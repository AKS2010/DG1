import uuid
from dataclasses import dataclass
from datetime import date, datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.role import Role, UserRole
from app.models.user import User


@dataclass(slots=True)
class AuthenticatedUser:
    user: User
    roles: list[str]


class AuthService:
    @staticmethod
    async def get_user_by_email(
        db: AsyncSession, email: str, tenant_id: uuid.UUID | None = None
    ) -> User | None:
        normalized = email.strip().lower()
        query = select(User).where(User.email == normalized, User.is_deleted.is_(False))
        if tenant_id is not None:
            query = query.where(User.tenant_id == tenant_id)
        # When tenant is not supplied, emails are unique per tenant but we still pick a single deterministic row.
        query = query.order_by(User.created_at.asc()).limit(1)
        return (await db.execute(query)).scalars().first()

    @staticmethod
    async def get_active_role_codes(db: AsyncSession, user_id: uuid.UUID) -> list[str]:
        today = date.today()
        query = (
            select(Role.role_code)
            .join(UserRole, UserRole.role_id == Role.id)
            .where(
                UserRole.user_id == user_id,
                UserRole.is_active.is_(True),
                Role.is_active.is_(True),
                Role.is_deleted.is_(False),
                UserRole.effective_from <= today,
                (UserRole.effective_to.is_(None)) | (UserRole.effective_to >= today),
            )
        )
        result = await db.execute(query)
        return sorted({row for row in result.scalars().all() if row})

    @staticmethod
    async def record_successful_login(db: AsyncSession, user: User) -> None:
        now = datetime.now(timezone.utc)
        user.last_login_at = now
        user.failed_login_count = 0
        await db.commit()

    @staticmethod
    async def record_failed_login(db: AsyncSession, user: User, lockout_threshold: int = 5) -> None:
        user.failed_login_count = (user.failed_login_count or 0) + 1
        if user.failed_login_count >= lockout_threshold and not user.is_locked:
            user.is_locked = True
            user.locked_at = datetime.now(timezone.utc)
        await db.commit()
