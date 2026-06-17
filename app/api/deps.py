import uuid

from fastapi import Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordBearer

from app.core.security import decode_access_token, is_dev_auth_enabled, is_jwt_error, parse_uuid

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


class PrincipalContext:
    def __init__(
        self,
        actor_id: uuid.UUID,
        tenant_id: uuid.UUID,
        permissions: set[str],
        auth_method: str,
        roles: set[str] | None = None,
        email: str | None = None,
    ) -> None:
        self.actor_id = actor_id
        self.tenant_id = tenant_id
        self.permissions = permissions
        self.roles = roles or set()
        self.email = email
        self.auth_method = auth_method


async def get_principal_context(
    request: Request,
    token: str = Depends(oauth2_scheme),
) -> PrincipalContext:
    try:
        payload = decode_access_token(token)
        actor_id = parse_uuid(str(payload["sub"]), "subject")
        tenant_id = parse_uuid(str(payload["tenant_id"]), "tenant_id")
    except (KeyError, ValueError) as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token payload") from exc
    except Exception as exc:
        if is_jwt_error(exc):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token") from exc
        raise

    auth_method = str(payload.get("auth_method", "bearer"))
    if auth_method == "dev_jwt" and not is_dev_auth_enabled():
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Developer authentication is disabled")

    permissions = {str(item).strip() for item in payload.get("permissions", []) if str(item).strip()}
    roles = {str(item).strip() for item in payload.get("roles", []) if str(item).strip()}
    email_claim = payload.get("email")
    email = str(email_claim).strip().lower() if email_claim else None
    principal = PrincipalContext(
        actor_id=actor_id,
        tenant_id=tenant_id,
        permissions=permissions,
        auth_method=auth_method,
        roles=roles,
        email=email,
    )
    request.state.principal = principal
    return principal


def require_permission(permission_code: str):
    async def dependency(ctx: PrincipalContext = Depends(get_principal_context)) -> PrincipalContext:
        if ctx.auth_method == "dev_jwt":
            return ctx
        if permission_code not in ctx.permissions:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Insufficient permissions")
        return ctx

    return dependency


def require_role(*role_codes: str):
    allowed = {code.strip() for code in role_codes if code and code.strip()}

    async def dependency(ctx: PrincipalContext = Depends(get_principal_context)) -> PrincipalContext:
        if not allowed.intersection(ctx.roles):
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Insufficient role")
        return ctx

    return dependency
