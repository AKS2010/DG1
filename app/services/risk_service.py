import uuid
from datetime import datetime, timezone

from sqlalchemy import Integer, func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.risk import Risk
from app.schemas.risk import RiskCreate, RiskUpdate


class RiskService:
    @staticmethod
    async def _next_risk_code(db: AsyncSession, tenant_id: uuid.UUID) -> str:
        """Generate the next risk code in format RSK-001, RSK-002, ..."""
        query = (
            select(func.max(
                func.cast(
                    func.substr(Risk.risk_code, 5),
                    Integer,
                )
            ))
            .where(Risk.tenant_id == tenant_id, Risk.risk_code.like("RSK-%"))
        )
        result = await db.execute(query)
        max_num = result.scalar() or 0
        return f"RSK-{max_num + 1:03d}"
    @staticmethod
    async def list_risks(
        db: AsyncSession,
        tenant_id: uuid.UUID,
        page: int,
        page_size: int,
    ) -> tuple[list[Risk], int]:
        base = select(Risk).where(Risk.tenant_id == tenant_id, Risk.is_deleted.is_(False))
        count_q = select(func.count()).select_from(Risk).where(Risk.tenant_id == tenant_id, Risk.is_deleted.is_(False))

        total = int((await db.execute(count_q)).scalar_one())
        result = await db.execute(
            base.order_by(Risk.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
        )
        return list(result.scalars().all()), total

    @staticmethod
    async def get_risk(db: AsyncSession, tenant_id: uuid.UUID, risk_id: uuid.UUID) -> Risk | None:
        query = select(Risk).where(Risk.id == risk_id, Risk.tenant_id == tenant_id, Risk.is_deleted.is_(False))
        return (await db.execute(query)).scalars().first()

    @staticmethod
    async def create_risk(db: AsyncSession, payload: RiskCreate, actor_id: uuid.UUID) -> Risk:
        now = datetime.now(timezone.utc)
        risk_code = payload.risk_code or await RiskService._next_risk_code(db, payload.tenant_id)
        risk = Risk(
            id=uuid.uuid4(),
            tenant_id=payload.tenant_id,
            entity_id=payload.entity_id,
            risk_code=risk_code,
            rist_type=payload.rist_type,
            description=payload.description,
            risk_category=payload.risk_category,
            coso=payload.coso,
            risk_reference=payload.risk_reference,
            risk_type=payload.risk_type.value,
            business_unit=payload.business_unit,
            location=payload.location,
            root_cause=payload.root_cause,
            risk_event=payload.risk_event,
            impact_description=payload.impact_description,
            risk_owner_id=payload.risk_owner_id,
            risk_delegate_id=payload.risk_delegate_id,
            likelihood=payload.likelihood,
            impact=payload.impact,
            risk_assertion_type=payload.risk_assertion_type,
            risk_assertion=payload.risk_assertion,
            risk_owner=payload.risk_owner,
            control_reference=payload.control_reference,
            control_description=payload.control_description,
            control_type=payload.control_type.value if payload.control_type else None,
            prepared_by=payload.prepared_by,
            reviewed_by=payload.reviewed_by,
            frequency=payload.frequency.value if payload.frequency else None,
            control_effectiveness_type=payload.control_effectiveness_type,
            control_effectiveness=payload.control_effectiveness,
            ipe=payload.ipe,
            cia_triad=payload.cia_triad,
            risk_treatment=payload.risk_treatment,
            status=payload.status.value,
            custom_attributes=payload.custom_attributes,
            tags=payload.tags,
            created_at=now,
            created_by=actor_id,
            modified_at=now,
            modified_by=actor_id,
            is_deleted=False,
            version=1,
        )
        db.add(risk)
        try:
            await db.commit()
        except IntegrityError as exc:
            await db.rollback()
            orig = exc.orig
            sqlstate = getattr(orig, "sqlstate", "") or getattr(getattr(orig, "__cause__", None), "sqlstate", "")
            if sqlstate == "23505":
                raise ValueError("Risk with this code already exists for the tenant/entity") from exc
            if sqlstate == "23503":
                detail = str(exc.orig)
                raise ValueError(f"Referenced record does not exist: {detail}") from exc
            raise ValueError(f"Unable to create risk: {exc.orig}") from exc
        await db.refresh(risk)
        return risk

    @staticmethod
    async def update_risk(db: AsyncSession, risk: Risk, payload: RiskUpdate, actor_id: uuid.UUID) -> Risk:
        update_map = payload.model_dump(exclude_unset=True)

        # Convert enum values to strings for DB storage
        for enum_field in ("risk_type", "control_type", "frequency", "status"):
            if enum_field in update_map and update_map[enum_field] is not None:
                update_map[enum_field] = update_map[enum_field].value

        for key, value in update_map.items():
            setattr(risk, key, value)

        risk.modified_at = datetime.now(timezone.utc)
        risk.modified_by = actor_id
        risk.version = (risk.version or 1) + 1

        try:
            await db.commit()
        except IntegrityError as exc:
            await db.rollback()
            sqlstate = getattr(exc.orig, "sqlstate", "")
            if sqlstate == "23505":
                raise ValueError("Risk update violates unique constraints") from exc
            raise ValueError("Unable to update risk due to data integrity rules") from exc
        await db.refresh(risk)
        return risk
