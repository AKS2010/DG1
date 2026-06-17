-- ============================================================================
-- eNFeNITE GRC Intelligence Platform - PostgreSQL Schema
-- Module: Compliance Obligations
-- Sub-modules: Compliance Calendar, Obligation Register, Regulatory Update Log,
--              Compliance Status Reports, Evidence Linking
-- ============================================================================

-- ============================================================================
-- OBLIGATION REGISTER
-- ============================================================================

CREATE TABLE compliance_obligations (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    entity_id               UUID NOT NULL REFERENCES entities(id),
    
    obligation_code         VARCHAR(50) NOT NULL,
    obligation_title        VARCHAR(500) NOT NULL,
    description             TEXT,
    
    -- Classification
    obligation_type         VARCHAR(100) NOT NULL,    -- 'statutory', 'regulatory', 'contractual', 'internal', 'industry'
    category                VARCHAR(200),             -- 'tax', 'labour', 'corporate', 'data_privacy', 'environmental', 'sector_specific'
    sub_category            VARCHAR(200),
    
    -- Regulatory source
    legislation             VARCHAR(500),             -- e.g., 'Income Tax Act, 1961'
    section_reference       VARCHAR(200),             -- e.g., 'Section 139(1)'
    regulatory_body         VARCHAR(300),             -- e.g., 'CBDT', 'MCA', 'SEBI'
    
    -- Framework link
    framework_id            UUID REFERENCES frameworks(id),
    framework_requirement_id UUID REFERENCES framework_requirements(id),
    
    -- Recurrence
    is_recurring            BOOLEAN NOT NULL DEFAULT TRUE,
    frequency               frequency_type NOT NULL DEFAULT 'annual',
    
    -- Due date logic
    base_due_day            INTEGER,                  -- day of month (e.g., 15)
    base_due_month          INTEGER,                  -- month of year (e.g., 7 for July)
    due_date_description    TEXT,                     -- human-readable: "15th of the month following quarter end"
    advance_alert_days      INTEGER DEFAULT 7,
    
    -- Ownership
    responsible_person_id   UUID NOT NULL REFERENCES users(id),
    reviewer_id             UUID REFERENCES users(id),
    department              VARCHAR(200),
    
    -- Applicability
    applicable_from         DATE,
    applicable_to           DATE,
    
    -- Penalty / Risk
    penalty_description     TEXT,
    penalty_amount          NUMERIC(15,2),
    penalty_currency        VARCHAR(10) DEFAULT 'INR',
    risk_level              priority_level DEFAULT 'medium',
    
    -- Status
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    status                  lifecycle_status NOT NULL DEFAULT 'active',
    
    custom_attributes       JSONB DEFAULT '{}',
    tags                    TEXT[] DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID NOT NULL REFERENCES users(id),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID REFERENCES users(id),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE(tenant_id, entity_id, obligation_code)
);

CREATE INDEX idx_obligations_tenant_entity ON compliance_obligations(tenant_id, entity_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_obligations_type ON compliance_obligations(tenant_id, obligation_type) WHERE is_deleted = FALSE;
CREATE INDEX idx_obligations_responsible ON compliance_obligations(responsible_person_id) WHERE is_deleted = FALSE AND is_active = TRUE;
CREATE INDEX idx_obligations_category ON compliance_obligations(tenant_id, category) WHERE is_deleted = FALSE;
CREATE INDEX idx_obligations_custom_attrs ON compliance_obligations USING GIN (custom_attributes) WHERE is_deleted = FALSE;

-- ============================================================================
-- COMPLIANCE CALENDAR (Instance-level tracking for each due period)
-- ============================================================================

CREATE TABLE compliance_calendar_items (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    entity_id               UUID NOT NULL REFERENCES entities(id),
    obligation_id           UUID NOT NULL REFERENCES compliance_obligations(id),
    period_id               UUID REFERENCES financial_periods(id),
    
    -- Instance details
    due_date                DATE NOT NULL,
    extended_due_date       DATE,                     -- if extension granted
    extension_reason        TEXT,
    
    -- Completion
    completion_date         DATE,
    completed_by            UUID REFERENCES users(id),
    
    -- Status & Compliance
    compliance_status       compliance_status NOT NULL DEFAULT 'pending_review',
    status_notes            TEXT,
    
    -- Filing details (for statutory filings)
    filing_reference        VARCHAR(200),             -- acknowledgment number, challan no, etc.
    filing_amount           NUMERIC(15,2),
    filing_currency         VARCHAR(10) DEFAULT 'INR',
    
    -- Assignment
    assigned_to             UUID REFERENCES users(id),
    reviewed_by             UUID REFERENCES users(id),
    reviewed_at             TIMESTAMPTZ,
    
    -- Reminders
    reminder_sent           BOOLEAN DEFAULT FALSE,
    reminder_count          INTEGER DEFAULT 0,
    last_reminder_at        TIMESTAMPTZ,
    
    -- Escalation
    is_escalated            BOOLEAN DEFAULT FALSE,
    escalated_to            UUID REFERENCES users(id),
    escalated_at            TIMESTAMPTZ,
    
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID REFERENCES users(id),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID REFERENCES users(id),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_compliance_calendar_tenant ON compliance_calendar_items(tenant_id, entity_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_compliance_calendar_due ON compliance_calendar_items(due_date) WHERE is_deleted = FALSE AND compliance_status NOT IN ('compliant', 'not_applicable');
CREATE INDEX idx_compliance_calendar_obligation ON compliance_calendar_items(obligation_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_compliance_calendar_status ON compliance_calendar_items(tenant_id, compliance_status) WHERE is_deleted = FALSE;
CREATE INDEX idx_compliance_calendar_assigned ON compliance_calendar_items(assigned_to, due_date) WHERE is_deleted = FALSE AND compliance_status = 'pending_review';

-- ============================================================================
-- REGULATORY UPDATE LOG
-- ============================================================================

CREATE TABLE regulatory_updates (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    
    update_code             VARCHAR(50) NOT NULL,
    title                   VARCHAR(500) NOT NULL,
    description             TEXT NOT NULL,
    
    -- Source
    regulatory_body         VARCHAR(300),
    legislation             VARCHAR(500),
    notification_reference  VARCHAR(200),             -- gazette no, circular no
    notification_date       DATE,
    effective_date          DATE,
    
    -- Impact Assessment
    impact_summary          TEXT,
    affected_obligations    UUID[] DEFAULT '{}',      -- array of obligation IDs
    impact_level            priority_level DEFAULT 'medium',
    
    -- Action Required
    action_required         TEXT,
    action_due_date         DATE,
    assigned_to             UUID REFERENCES users(id),
    
    -- Status
    status                  VARCHAR(50) NOT NULL DEFAULT 'new', -- 'new', 'under_review', 'assessed', 'implemented', 'not_applicable'
    
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID NOT NULL REFERENCES users(id),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID REFERENCES users(id),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE(tenant_id, update_code)
);

CREATE INDEX idx_regulatory_updates_tenant ON regulatory_updates(tenant_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_regulatory_updates_status ON regulatory_updates(tenant_id, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_regulatory_updates_effective ON regulatory_updates(effective_date) WHERE is_deleted = FALSE;
