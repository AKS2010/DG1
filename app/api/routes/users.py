import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import PrincipalContext, get_principal_context, require_permission
from app.core.database import get_db_session
from app.schemas.user import UserCreate, UserListResponse, UserRead, UserUpdate
from app.services.user_service import UserService

router = APIRouter(prefix="/users", tags=["users"])


@router.get(
    "",
    response_model=UserListResponse,
    dependencies=[Depends(require_permission("users.read"))],
)
async def list_users(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: AsyncSession = Depends(get_db_session),
    ctx: PrincipalContext = Depends(get_principal_context),
) -> UserListResponse:
    users, total = await UserService.list_users(db, tenant_id=ctx.tenant_id, page=page, page_size=page_size)
    return UserListResponse(items=[UserRead.model_validate(item) for item in users], total=total, page=page, page_size=page_size)


@router.get(
    "/{user_id}",
    response_model=UserRead,
    dependencies=[Depends(require_permission("users.read"))],
)
async def get_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db_session),
    ctx: PrincipalContext = Depends(get_principal_context),
) -> UserRead:
    user = await UserService.get_user(db, tenant_id=ctx.tenant_id, user_id=user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return UserRead.model_validate(user)


@router.post(
    "",
    response_model=UserRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_permission("users.write"))],
)
async def create_user(
    payload: UserCreate,
    db: AsyncSession = Depends(get_db_session),
    ctx: PrincipalContext = Depends(get_principal_context),
) -> UserRead:
    if payload.tenant_id != ctx.tenant_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Cross-tenant user creation is not allowed")
    try:
        user = await UserService.create_user(db, payload, actor_id=ctx.actor_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    return UserRead.model_validate(user)


@router.patch(
    "/{user_id}",
    response_model=UserRead,
    dependencies=[Depends(require_permission("users.write"))],
)
async def update_user(
    user_id: uuid.UUID,
    payload: UserUpdate,
    db: AsyncSession = Depends(get_db_session),
    ctx: PrincipalContext = Depends(get_principal_context),
) -> UserRead:
    user = await UserService.get_user(db, tenant_id=ctx.tenant_id, user_id=user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    try:
        updated = await UserService.update_user(db, user, payload, actor_id=ctx.actor_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    return UserRead.model_validate(updated)


@router.delete(
    "/{user_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(require_permission("users.delete"))],
)
async def delete_user(
    user_id: uuid.UUID,
    db: AsyncSession = Depends(get_db_session),
    ctx: PrincipalContext = Depends(get_principal_context),
) -> None:
    user = await UserService.get_user(db, tenant_id=ctx.tenant_id, user_id=user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    await UserService.soft_delete_user(db, user, actor_id=ctx.actor_id)
