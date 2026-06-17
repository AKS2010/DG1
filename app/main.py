from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.router import api_router
from app.core.audit_sink import BlobAuditSink
from app.core.config import settings
from app.core.database import close_db, init_db
from app.core.logging import configure_logging
from app.middleware.audit import RequestAuditMiddleware

audit_sink = BlobAuditSink()


@asynccontextmanager
async def lifespan(app: FastAPI):
    configure_logging(settings.app_log_level)
    await init_db()
    await audit_sink.start()
    yield
    await audit_sink.stop()
    await close_db()


app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    docs_url="/docs" if settings.app_env != "prod" else None,
    redoc_url="/redoc" if settings.app_env != "prod" else None,
    lifespan=lifespan,
)

app.add_middleware(RequestAuditMiddleware, audit_sink=audit_sink)
app.include_router(api_router, prefix="/api/v1")
