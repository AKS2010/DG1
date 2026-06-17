import uuid
from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class RiskTypeEnum(str, Enum):
    financial = "financial"
    operational = "operational"
    compliance = "compliance"
    it_cyber = "it_cyber"
    fraud = "fraud"
    reporting = "reporting"
    third_party = "third_party"
    strategic = "strategic"


class LifecycleStatusEnum(str, Enum):
    draft = "draft"
    under_review = "under_review"
    approved = "approved"
    active = "active"
    closed = "closed"
    archived = "archived"
    rejected = "rejected"


class ControlTypeEnum(str, Enum):
    preventive = "preventive"
    detective = "detective"
    corrective = "corrective"


class FrequencyTypeEnum(str, Enum):
    daily = "daily"
    weekly = "weekly"
    fortnightly = "fortnightly"
    monthly = "monthly"
    quarterly = "quarterly"
    semi_annual = "semi_annual"
    annual = "annual"
    ad_hoc = "ad_hoc"
    continuous = "continuous"


class RiskCreate(BaseModel):
    tenant_id: uuid.UUID
    entity_id: uuid.UUID | None = None
    risk_code: str | None = Field(default=None, max_length=50)
    rist_type: str = Field(max_length=200)
    description: str | None = None
    risk_category: str = Field(max_length=100)
    coso: str | None = Field(default=None, max_length=100)
    risk_reference: str | None = Field(default=None, max_length=200)
    risk_type: RiskTypeEnum | None = None
    business_unit: str | None = Field(default=None, max_length=200)
    location: str | None = Field(default=None, max_length=200)

    root_cause: str | None = None
    risk_event: str | None = None
    impact_description: str | None = None

    risk_owner_id: uuid.UUID | None = None
    risk_delegate_id: uuid.UUID | None = None

    likelihood: int | None = Field(default=None, ge=1, le=5)
    impact: int | None = Field(default=None, ge=1, le=5)
    risk_assertion_type: str | None = Field(default=None, max_length=200)
    risk_assertion: str | None = Field(default=None, max_length=200)

    risk_owner: uuid.UUID | None = None
    control_reference: str | None = Field(default=None, max_length=200)
    control_description: str | None = None
    control_type: ControlTypeEnum | None = None
    prepared_by: uuid.UUID | None = None
    reviewed_by: uuid.UUID | None = None
    frequency: FrequencyTypeEnum | None = None
    control_effectiveness_type: str | None = Field(default=None, max_length=100)
    control_effectiveness: bool | None = None
    ipe: str | None = Field(default=None, max_length=200)

    cia_triad: str | None = Field(default=None, max_length=100)
    risk_treatment: str | None = Field(default=None, max_length=100)

    status: LifecycleStatusEnum = LifecycleStatusEnum.draft

    custom_attributes: dict = Field(default_factory=dict)
    tags: list[str] = Field(default_factory=list)


class RiskUpdate(BaseModel):
    entity_id: uuid.UUID | None = None
    rist_type: str | None = Field(default=None, max_length=200)
    description: str | None = None
    risk_category: str | None = Field(default=None, max_length=100)
    coso: str | None = Field(default=None, max_length=100)
    risk_reference: str | None = Field(default=None, max_length=200)
    risk_type: RiskTypeEnum | None = None
    business_unit: str | None = Field(default=None, max_length=200)
    location: str | None = Field(default=None, max_length=200)

    root_cause: str | None = None
    risk_event: str | None = None
    impact_description: str | None = None

    risk_owner_id: uuid.UUID | None = None
    risk_delegate_id: uuid.UUID | None = None

    likelihood: int | None = Field(default=None, ge=1, le=5)
    impact: int | None = Field(default=None, ge=1, le=5)
    risk_assertion_type: str | None = Field(default=None, max_length=200)
    risk_assertion: str | None = Field(default=None, max_length=200)

    risk_owner: uuid.UUID | None = None
    control_reference: str | None = Field(default=None, max_length=200)
    control_description: str | None = None
    control_type: ControlTypeEnum | None = None
    prepared_by: uuid.UUID | None = None
    reviewed_by: uuid.UUID | None = None
    frequency: FrequencyTypeEnum | None = None
    control_effectiveness_type: str | None = Field(default=None, max_length=100)
    control_effectiveness: bool | None = None
    ipe: str | None = Field(default=None, max_length=200)

    cia_triad: str | None = Field(default=None, max_length=100)
    risk_treatment: str | None = Field(default=None, max_length=100)

    status: LifecycleStatusEnum | None = None
    approved_by: uuid.UUID | None = None

    custom_attributes: dict | None = None
    tags: list[str] | None = None


class RiskRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    tenant_id: uuid.UUID
    entity_id: uuid.UUID
    risk_code: str
    rist_type: str
    description: str | None
    risk_category: str
    coso: str | None
    risk_reference: str | None
    risk_type: str
    business_unit: str | None
    location: str | None

    root_cause: str | None
    risk_event: str | None
    impact_description: str | None

    risk_owner_id: uuid.UUID
    risk_delegate_id: uuid.UUID | None

    likelihood: int
    impact: int
    risk_score: float | None
    risk_assertion_type: str | None
    risk_assertion: str | None

    risk_owner: uuid.UUID | None
    control_reference: str | None
    control_description: str | None
    control_type: str | None
    prepared_by: uuid.UUID | None
    reviewed_by: uuid.UUID | None
    frequency: str | None
    control_effectiveness_type: str | None
    control_effectiveness: bool | None
    ipe: str | None

    cia_triad: str | None
    risk_treatment: str | None

    status: str
    approved_by: uuid.UUID | None
    approved_at: datetime | None

    custom_attributes: dict
    tags: list[str]

    created_at: datetime
    created_by: uuid.UUID
    modified_at: datetime
    modified_by: uuid.UUID | None
    is_deleted: bool
    version: int


class RiskListResponse(BaseModel):
    items: list[RiskRead]
    total: int
    page: int
    page_size: int
