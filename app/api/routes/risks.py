import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import PrincipalContext, get_principal_context, require_permission
from app.core.database import get_db_session
from app.schemas.risk import RiskCreate, RiskListResponse, RiskRead, RiskUpdate
from app.services.risk_service import RiskService

router = APIRouter(prefix="/risks", tags=["risks"])


@router.get(
    "",
    response_model=RiskListResponse,
    dependencies=[Depends(require_permission("risks.read"))],
)
async def list_risks(
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
    db: AsyncSession = Depends(get_db_session),
    ctx: PrincipalContext = Depends(get_principal_context),
) -> RiskListResponse:
    risks, total = await RiskService.list_risks(db, tenant_id=ctx.tenant_id, page=page, page_size=page_size)
    return RiskListResponse(items=[RiskRead.model_validate(item) for item in risks], total=total, page=page, page_size=page_size)


@router.get(
    "/{risk_id}",
    response_model=RiskRead,
    dependencies=[Depends(require_permission("risks.read"))],
)
async def get_risk(
    risk_id: uuid.UUID,
    db: AsyncSession = Depends(get_db_session),
    ctx: PrincipalContext = Depends(get_principal_context),
) -> RiskRead:
    risk = await RiskService.get_risk(db, tenant_id=ctx.tenant_id, risk_id=risk_id)
    if risk is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Risk not found")
    return RiskRead.model_validate(risk)


@router.post(
    "",
    response_model=RiskRead,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_permission("risks.write"))],
)
async def create_risk(
    payload: RiskCreate,
    db: AsyncSession = Depends(get_db_session),
    ctx: PrincipalContext = Depends(get_principal_context),
) -> RiskRead:
    if payload.tenant_id != ctx.tenant_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Cross-tenant risk creation is not allowed")
    try:
        risk = await RiskService.create_risk(db, payload, actor_id=ctx.actor_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    return RiskRead.model_validate(risk)


@router.patch(
    "/{risk_id}",
    response_model=RiskRead,
    dependencies=[Depends(require_permission("risks.write"))],
)
async def update_risk(
    risk_id: uuid.UUID,
    payload: RiskUpdate,
    db: AsyncSession = Depends(get_db_session),
    ctx: PrincipalContext = Depends(get_principal_context),
) -> RiskRead:
    risk = await RiskService.get_risk(db, tenant_id=ctx.tenant_id, risk_id=risk_id)
    if risk is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Risk not found")
    try:
        updated = await RiskService.update_risk(db, risk, payload, actor_id=ctx.actor_id)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc)) from exc
    return RiskRead.model_validate(updated)
