import uuid
from datetime import datetime

from sqlalchemy import Boolean, Computed, DateTime, Enum, Integer, Numeric, String, Text, func, text
from sqlalchemy.dialects.postgresql import ARRAY, JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base

# PostgreSQL enum types (already created in DB via 00_extensions_and_types.sql)
_risk_type_enum = Enum(
    'financial', 'operational', 'compliance', 'it_cyber', 'fraud', 'reporting', 'third_party', 'strategic',
    name='risk_type', create_type=False,
)
_control_type_enum = Enum(
    'preventive', 'detective', 'corrective',
    name='control_type', create_type=False,
)
_frequency_type_enum = Enum(
    'daily', 'weekly', 'fortnightly', 'monthly', 'quarterly', 'semi_annual', 'annual', 'ad_hoc', 'continuous',
    name='frequency_type', create_type=False,
)
_lifecycle_status_enum = Enum(
    'draft', 'under_review', 'approved', 'active', 'closed', 'archived', 'rejected',
    name='lifecycle_status', create_type=False,
)


class Risk(Base):
    __tablename__ = "risks"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
        server_default=text("gen_random_uuid()"),
    )
    tenant_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    entity_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)

    # Identification
    risk_code: Mapped[str] = mapped_column(String(50), nullable=False)
    rist_type: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    risk_category: Mapped[str] = mapped_column(String(100), nullable=False)
    coso: Mapped[str | None] = mapped_column(String(100), nullable=True)
    risk_reference: Mapped[str | None] = mapped_column(String(200), nullable=True)
    risk_type: Mapped[str] = mapped_column(_risk_type_enum, nullable=False)
    business_unit: Mapped[str | None] = mapped_column(String(200), nullable=True)
    location: Mapped[str | None] = mapped_column(String(200), nullable=True)

    # Description & Context
    root_cause: Mapped[str | None] = mapped_column(Text, nullable=True)
    risk_event: Mapped[str | None] = mapped_column(Text, nullable=True)
    impact_description: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Ownership
    risk_owner_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    risk_delegate_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)

    # Inherent Risk Assessment
    likelihood: Mapped[int] = mapped_column(Integer, nullable=False)
    impact: Mapped[int] = mapped_column(Integer, nullable=False)
    risk_score: Mapped[float | None] = mapped_column(Numeric(5, 2), Computed("likelihood * impact", persisted=True), nullable=True)
    risk_assertion_type: Mapped[str | None] = mapped_column(String(200), nullable=True)
    risk_assertion: Mapped[str | None] = mapped_column(String(200), nullable=True)

    risk_owner: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    control_reference: Mapped[str | None] = mapped_column(String(200), nullable=True)
    control_description: Mapped[str | None] = mapped_column(Text, nullable=True)
    control_type: Mapped[str | None] = mapped_column(_control_type_enum, nullable=True)
    prepared_by: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    reviewed_by: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    frequency: Mapped[str | None] = mapped_column(_frequency_type_enum, nullable=True)
    control_effectiveness_type: Mapped[str | None] = mapped_column(String(100), nullable=True)
    control_effectiveness: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    ipe: Mapped[str | None] = mapped_column(String(200), nullable=True)

    # IT/Cyber Risks
    cia_triad: Mapped[str | None] = mapped_column(String(100), nullable=True)
    risk_treatment: Mapped[str | None] = mapped_column(String(100), nullable=True)

    # Workflow
    status: Mapped[str] = mapped_column(_lifecycle_status_enum, nullable=False, server_default=text("'draft'"))
    approved_by: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    approved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Dynamic fields
    custom_attributes: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict, server_default=text("'{}'::jsonb"))
    tags: Mapped[list] = mapped_column(ARRAY(Text), nullable=False, default=list, server_default=text("'{}'::text[]"))

    # Standard Audit Fields
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    created_by: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    modified_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    modified_by: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    is_deleted: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default=text("false"))
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    deleted_by: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    version: Mapped[int] = mapped_column(Integer, nullable=False, default=1, server_default=text("1"))
