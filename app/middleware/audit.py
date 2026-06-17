import json
import time
import uuid
from collections.abc import Awaitable, Callable

import structlog
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware

from app.core.audit_sink import BlobAuditSink

logger = structlog.get_logger(__name__)


class RequestAuditMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, audit_sink: BlobAuditSink | None = None) -> None:
        super().__init__(app)
        self.audit_sink = audit_sink

    async def dispatch(self, request: Request, call_next: Callable[[Request], Awaitable[Response]]) -> Response:
        request_id = request.headers.get("x-request-id") or str(uuid.uuid4())
        start = time.perf_counter()

        response = await call_next(request)
        duration_ms = round((time.perf_counter() - start) * 1000, 2)

        principal = getattr(request.state, "principal", None)

        response.headers["x-request-id"] = request_id

        audit_record = {
            "request_id": request_id,
            "tenant_id": str(principal.tenant_id) if principal else None,
            "actor_id": str(principal.actor_id) if principal else None,
            "auth_method": principal.auth_method if principal else None,
            "method": request.method,
            "path": request.url.path,
            "query_keys": sorted(list(request.query_params.keys())),
            "status_code": response.status_code,
            "latency_ms": duration_ms,
            "client_ip": request.client.host if request.client else None,
            "user_agent": request.headers.get("user-agent"),
        }

        logger.info("api_request", **audit_record)

        if self.audit_sink:
            await self.audit_sink.enqueue(json.dumps(audit_record, separators=(",", ":")))

        return response
