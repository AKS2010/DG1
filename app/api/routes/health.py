from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import APIRouter, Depends

from app.core.database import get_db_session
from app.schemas.health import HealthResponse, ReadinessResponse

router = APIRouter(prefix="/health", tags=["health"])


@router.get("/live", response_model=HealthResponse)
async def liveness() -> HealthResponse:
    return HealthResponse(status="ok")


@router.get("/ready", response_model=ReadinessResponse)
async def readiness(db: AsyncSession = Depends(get_db_session)) -> ReadinessResponse:
    database_state = "ok"
    try:
        await db.execute(text("SELECT 1"))
    except Exception:
        database_state = "down"
    status_value = "ok" if database_state == "ok" else "degraded"
    return ReadinessResponse(status=status_value, database=database_state)
