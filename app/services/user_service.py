import uuid
from datetime import datetime, timezone

from sqlalchemy.exc import IntegrityError
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import pwd_context
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate


class UserService:
    @staticmethod
    async def _get_user_by_email(db: AsyncSession, tenant_id: uuid.UUID, email: str) -> User | None:
        query = select(User).where(User.tenant_id == tenant_id, User.email == email)
        return (await db.execute(query)).scalars().first()

    @staticmethod
    async def list_users(
        db: AsyncSession,
        tenant_id: uuid.UUID,
        page: int,
        page_size: int,
    ) -> tuple[list[User], int]:
        base_query = select(User).where(User.tenant_id == tenant_id, User.is_deleted.is_(False))
        count_query = select(func.count()).select_from(User).where(User.tenant_id == tenant_id, User.is_deleted.is_(False))

        total = int((await db.execute(count_query)).scalar_one())
        result = await db.execute(
            base_query.order_by(User.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
        )
        return list(result.scalars().all()), total

    @staticmethod
    async def get_user(db: AsyncSession, tenant_id: uuid.UUID, user_id: uuid.UUID) -> User | None:
        query = select(User).where(User.id == user_id, User.tenant_id == tenant_id, User.is_deleted.is_(False))
        return (await db.execute(query)).scalars().first()

    @staticmethod
    async def create_user(db: AsyncSession, payload: UserCreate, actor_id: uuid.UUID) -> User:
        normalized_email = str(payload.email).strip().lower()
        existing = await UserService._get_user_by_email(db, payload.tenant_id, normalized_email)
        if existing and not existing.is_deleted:
            raise ValueError("User with this email already exists for the tenant")
        if existing and existing.is_deleted:
            raise ValueError("A deleted user with this email already exists for the tenant")

        now = datetime.now(timezone.utc)
        user = User(
            id=uuid.uuid4(),
            tenant_id=payload.tenant_id,
            email=normalized_email,
            password_hash=pwd_context.hash(payload.password) if payload.password else None,
            first_name=payload.first_name,
            last_name=payload.last_name,
            display_name=payload.display_name,
            phone=payload.phone,
            designation=payload.designation,
            department=payload.department,
            auth_provider=payload.auth_provider,
            external_id=payload.external_id,
            must_change_password=payload.must_change_password,
            mfa_enabled=payload.mfa_enabled,
            avatar_url=payload.avatar_url,
            preferences=payload.preferences,
            custom_attributes=payload.custom_attributes,
            is_locked=False,
            failed_login_count=0,
            password_changed_at=now if payload.password else None,
            is_active=True,
            is_deleted=False,
            created_at=now,
            created_by=actor_id,
            modified_at=now,
            modified_by=actor_id,
            deleted_at=None,
        )
        db.add(user)
        try:
            await db.commit()
        except IntegrityError as exc:
            await db.rollback()
            sqlstate = getattr(exc.orig, "sqlstate", "")
            if sqlstate == "23505":
                raise ValueError("User with this email already exists for the tenant") from exc
            if sqlstate == "23503":
                raise ValueError("Referenced tenant does not exist") from exc
            raise ValueError("Unable to create user due to data integrity rules") from exc
        await db.refresh(user)
        return user

    @staticmethod
    async def update_user(db: AsyncSession, user: User, payload: UserUpdate, actor_id: uuid.UUID) -> User:
        update_map = payload.model_dump(exclude_unset=True)
        raw_password = update_map.pop("password", None)

        incoming_email = update_map.pop("email", None)
        if incoming_email is not None:
            normalized_email = str(incoming_email).strip().lower()
            if normalized_email != user.email:
                existing = await UserService._get_user_by_email(db, user.tenant_id, normalized_email)
                if existing and existing.id != user.id and not existing.is_deleted:
                    raise ValueError("User with this email already exists for the tenant")
                if existing and existing.id != user.id and existing.is_deleted:
                    raise ValueError("A deleted user with this email already exists for the tenant")
                user.email = normalized_email

        for key, value in update_map.items():
            setattr(user, key, value)

        if raw_password:
            user.password_hash = pwd_context.hash(raw_password)
            user.password_changed_at = datetime.now(timezone.utc)

        if payload.is_locked is False:
            user.locked_at = None
            user.failed_login_count = 0
        elif payload.is_locked is True and not user.locked_at:
            user.locked_at = datetime.now(timezone.utc)

        user.modified_at = datetime.now(timezone.utc)
        user.modified_by = actor_id

        try:
            await db.commit()
        except IntegrityError as exc:
            await db.rollback()
            sqlstate = getattr(exc.orig, "sqlstate", "")
            if sqlstate == "23505":
                raise ValueError("User update violates unique constraints") from exc
            raise ValueError("Unable to update user due to data integrity rules") from exc
        await db.refresh(user)
        return user

    @staticmethod
    async def soft_delete_user(db: AsyncSession, user: User, actor_id: uuid.UUID) -> None:
        now = datetime.now(timezone.utc)
        user.is_deleted = True
        user.is_active = False
        user.deleted_at = now
        user.modified_at = now
        user.modified_by = actor_id
        await db.commit()
