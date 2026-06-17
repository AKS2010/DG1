from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import PrincipalContext, get_principal_context
from app.core.config import settings
from app.core.database import get_db_session
from app.core.security import (
    create_access_token,
    create_dev_access_token,
    get_jwks,
    get_public_key_pem,
    is_dev_auth_enabled,
    verify_password,
)
from app.schemas.auth import (
    DevTokenRequest,
    LoginRequest,
    PrincipalResponse,
    PublicKeyResponse,
    TokenResponse,
)
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["auth"])

_INVALID_CREDENTIALS = "Invalid email or password"


@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db_session)) -> TokenResponse:
    user = await AuthService.get_user_by_email(db, str(payload.email))
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=_INVALID_CREDENTIALS)
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User account is inactive")
    if user.is_locked:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="User account is locked")
    if not verify_password(payload.password, user.password_hash):
        await AuthService.record_failed_login(db, user)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=_INVALID_CREDENTIALS)

    roles = await AuthService.get_active_role_codes(db, user.id)
    token, ttl_minutes = create_access_token(
        user_id=user.id,
        tenant_id=user.tenant_id,
        email=user.email,
        roles=roles,
    )
    await AuthService.record_successful_login(db, user)

    return TokenResponse(
        access_token=token,
        expires_in_minutes=ttl_minutes,
        user_id=user.id,
        tenant_id=user.tenant_id,
        email=user.email,
        roles=roles,
    )


@router.post("/dev-token", response_model=TokenResponse)
async def create_dev_token(payload: DevTokenRequest) -> TokenResponse:
    if not is_dev_auth_enabled():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")

    token = create_dev_access_token(
        actor_id=payload.actor_id,
        tenant_id=payload.tenant_id,
        permissions=payload.permissions,
        expires_in_minutes=payload.expires_in_minutes,
    )
    return TokenResponse(
        access_token=token,
        expires_in_minutes=payload.expires_in_minutes,
        user_id=payload.actor_id,
        tenant_id=payload.tenant_id,
        roles=[],
    )


@router.get("/me", response_model=PrincipalResponse)
async def read_current_principal(ctx: PrincipalContext = Depends(get_principal_context)) -> PrincipalResponse:
    return PrincipalResponse(
        actor_id=ctx.actor_id,
        tenant_id=ctx.tenant_id,
        email=ctx.email,
        roles=sorted(ctx.roles),
        permissions=sorted(ctx.permissions),
        auth_method=ctx.auth_method,
    )


@router.get("/public-key", response_model=PublicKeyResponse)
async def read_public_key() -> PublicKeyResponse:
    return PublicKeyResponse(
        algorithm=settings.jwt_algorithm,
        key_id=settings.jwt_key_id,
        issuer=settings.jwt_issuer,
        audience=settings.jwt_audience,
        public_key_pem=get_public_key_pem(),
    )


@router.get("/.well-known/jwks.json")
async def read_jwks() -> dict:
    return get_jwks()
