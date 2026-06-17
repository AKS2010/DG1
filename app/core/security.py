import base64
import uuid
from datetime import UTC, datetime, timedelta
from functools import lru_cache

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import settings

pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")


class JWTKeyConfigurationError(RuntimeError):
    pass


@lru_cache(maxsize=1)
def _private_key_pem() -> str:
    if not settings.jwt_private_key:
        raise JWTKeyConfigurationError(
            "JWT_PRIVATE_KEY is not configured. Set it to a PEM-encoded RSA private key."
        )
    return settings.jwt_private_key


@lru_cache(maxsize=1)
def _public_key_pem() -> str:
    if settings.jwt_public_key:
        return settings.jwt_public_key
    try:
        private_key = serialization.load_pem_private_key(_private_key_pem().encode("utf-8"), password=None)
    except Exception as exc:  # noqa: BLE001 - surfaced as configuration error
        raise JWTKeyConfigurationError("JWT_PRIVATE_KEY is not a valid PEM-encoded key.") from exc
    if not isinstance(private_key, rsa.RSAPrivateKey):
        raise JWTKeyConfigurationError("JWT_PRIVATE_KEY must be an RSA private key for RS256.")
    public_pem = private_key.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    return public_pem.decode("utf-8")


def get_public_key_pem() -> str:
    return _public_key_pem()


def _int_to_base64url(value: int) -> str:
    byte_length = (value.bit_length() + 7) // 8
    raw = value.to_bytes(byte_length, "big")
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def get_jwks() -> dict:
    public_key = serialization.load_pem_public_key(_public_key_pem().encode("utf-8"))
    if not isinstance(public_key, rsa.RSAPublicKey):
        raise JWTKeyConfigurationError("Public key must be RSA for RS256 JWKS export.")
    numbers = public_key.public_numbers()
    return {
        "keys": [
            {
                "kty": "RSA",
                "use": "sig",
                "alg": settings.jwt_algorithm,
                "kid": settings.jwt_key_id,
                "n": _int_to_base64url(numbers.n),
                "e": _int_to_base64url(numbers.e),
            }
        ]
    }


def hash_password(plain_password: str) -> str:
    return pwd_context.hash(plain_password)


def verify_password(plain_password: str, password_hash: str | None) -> bool:
    if not password_hash:
        return False
    try:
        return pwd_context.verify(plain_password, password_hash)
    except Exception:  # noqa: BLE001 - malformed hash means auth failure
        return False


def create_access_token(
    *,
    user_id: uuid.UUID,
    tenant_id: uuid.UUID,
    email: str,
    roles: list[str],
    extra_claims: dict | None = None,
    expires_in_minutes: int | None = None,
) -> tuple[str, int]:
    ttl_minutes = expires_in_minutes if expires_in_minutes is not None else settings.access_token_expires_minutes
    now = datetime.now(UTC)
    payload: dict = {
        "sub": str(user_id),
        "user_id": str(user_id),
        "email": email,
        "tenant_id": str(tenant_id),
        "roles": sorted({role for role in roles if role}),
        "auth_method": "password",
        "iss": settings.jwt_issuer,
        "aud": settings.jwt_audience,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=ttl_minutes)).timestamp()),
    }
    if extra_claims:
        payload.update(extra_claims)
    token = jwt.encode(
        payload,
        _private_key_pem(),
        algorithm=settings.jwt_algorithm,
        headers={"kid": settings.jwt_key_id},
    )
    return token, ttl_minutes


def create_dev_access_token(
    *,
    actor_id: uuid.UUID,
    tenant_id: uuid.UUID,
    permissions: list[str],
    expires_in_minutes: int = 60,
) -> str:
    now = datetime.now(UTC)
    payload = {
        "sub": str(actor_id),
        "user_id": str(actor_id),
        "tenant_id": str(tenant_id),
        "permissions": permissions,
        "roles": [],
        "auth_method": "dev_jwt",
        "iss": settings.jwt_issuer,
        "aud": settings.jwt_audience,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=expires_in_minutes)).timestamp()),
    }
    return jwt.encode(
        payload,
        _private_key_pem(),
        algorithm=settings.jwt_algorithm,
        headers={"kid": settings.jwt_key_id},
    )


def decode_access_token(token: str) -> dict:
    return jwt.decode(
        token,
        _public_key_pem(),
        algorithms=[settings.jwt_algorithm],
        audience=settings.jwt_audience,
        issuer=settings.jwt_issuer,
    )


def parse_uuid(value: str, field_name: str) -> uuid.UUID:
    try:
        return uuid.UUID(value)
    except ValueError as exc:
        raise ValueError(f"Invalid {field_name}") from exc


def is_dev_auth_enabled() -> bool:
    return settings.app_env != "prod" and settings.enable_dev_auth


def is_jwt_error(exc: Exception) -> bool:
    return isinstance(exc, JWTError)
