from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


def _normalize_pem(value: str) -> str:
    cleaned = value.strip().strip('"').strip("'")
    return cleaned.replace("\\n", "\n")


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_name: str = Field(default="dg-api", alias="APP_NAME")
    app_env: str = Field(default="dev", alias="APP_ENV")
    app_port: int = Field(default=8000, alias="APP_PORT")
    app_log_level: str = Field(default="INFO", alias="APP_LOG_LEVEL")

    database_url: str = Field(alias="DATABASE_URL")

    enable_dev_auth: bool = Field(default=True, alias="ENABLE_DEV_AUTH")
    jwt_issuer: str = Field(default="dg-api", alias="JWT_ISSUER")
    jwt_audience: str = Field(default="dg-spa", alias="JWT_AUDIENCE")
    jwt_algorithm: str = Field(default="RS256", alias="JWT_ALGORITHM")
    jwt_key_id: str = Field(default="dg-api-key-1", alias="JWT_KEY_ID")
    jwt_private_key: str = Field(default="", alias="JWT_PRIVATE_KEY")
    jwt_public_key: str = Field(default="", alias="JWT_PUBLIC_KEY")
    access_token_expires_minutes: int = Field(default=60, ge=5, le=1440, alias="ACCESS_TOKEN_EXPIRES_MINUTES")

    azure_storage_account_url: str | None = Field(default=None, alias="AZURE_STORAGE_ACCOUNT_URL")
    azure_storage_container: str = Field(default="api-audit-logs", alias="AZURE_STORAGE_CONTAINER")

    @field_validator("jwt_private_key", "jwt_public_key", mode="after")
    @classmethod
    def _decode_pem(cls, value: str) -> str:
        return _normalize_pem(value) if value else value


settings = Settings()
