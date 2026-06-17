import uuid

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class DevTokenRequest(BaseModel):
    actor_id: uuid.UUID
    tenant_id: uuid.UUID
    permissions: list[str] = Field(default_factory=list)
    expires_in_minutes: int = Field(default=60, ge=5, le=1440)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=256)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in_minutes: int
    user_id: uuid.UUID | None = None
    tenant_id: uuid.UUID | None = None
    email: EmailStr | None = None
    roles: list[str] = Field(default_factory=list)


class PrincipalResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    actor_id: uuid.UUID
    tenant_id: uuid.UUID
    email: str | None = None
    roles: list[str] = Field(default_factory=list)
    permissions: list[str]
    auth_method: str


class PublicKeyResponse(BaseModel):
    algorithm: str
    key_id: str
    issuer: str
    audience: str
    public_key_pem: str
