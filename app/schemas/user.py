import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserCreate(BaseModel):
    tenant_id: uuid.UUID
    email: EmailStr
    first_name: str = Field(min_length=1, max_length=100)
    last_name: str | None = Field(default=None, max_length=100)
    display_name: str | None = Field(default=None, max_length=200)
    phone: str | None = Field(default=None, max_length=50)
    designation: str | None = Field(default=None, max_length=150)
    department: str | None = Field(default=None, max_length=150)
    auth_provider: str = Field(default="local", max_length=50)
    external_id: str | None = Field(default=None, max_length=255)
    must_change_password: bool = False
    mfa_enabled: bool = False
    avatar_url: str | None = Field(default=None, max_length=500)
    preferences: dict = Field(default_factory=dict)
    custom_attributes: dict = Field(default_factory=dict)
    password: str | None = Field(default=None, min_length=12, max_length=128)


class UserUpdate(BaseModel):
    email: EmailStr | None = None
    first_name: str | None = Field(default=None, min_length=1, max_length=100)
    last_name: str | None = Field(default=None, max_length=100)
    display_name: str | None = Field(default=None, max_length=200)
    phone: str | None = Field(default=None, max_length=50)
    designation: str | None = Field(default=None, max_length=150)
    department: str | None = Field(default=None, max_length=150)
    auth_provider: str | None = Field(default=None, max_length=50)
    external_id: str | None = Field(default=None, max_length=255)
    must_change_password: bool | None = None
    mfa_enabled: bool | None = None
    avatar_url: str | None = Field(default=None, max_length=500)
    preferences: dict | None = None
    custom_attributes: dict | None = None
    password: str | None = Field(default=None, min_length=12, max_length=128)
    is_locked: bool | None = None
    is_active: bool | None = None


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    tenant_id: uuid.UUID
    email: EmailStr
    first_name: str
    last_name: str | None
    display_name: str | None
    phone: str | None
    designation: str | None
    department: str | None
    auth_provider: str
    external_id: str | None
    must_change_password: bool
    mfa_enabled: bool
    avatar_url: str | None
    preferences: dict
    custom_attributes: dict
    is_locked: bool
    failed_login_count: int
    last_login_at: datetime | None
    password_changed_at: datetime | None
    is_active: bool
    created_at: datetime
    created_by: uuid.UUID | None
    modified_at: datetime
    modified_by: uuid.UUID | None


class UserListResponse(BaseModel):
    items: list[UserRead]
    total: int
    page: int
    page_size: int
