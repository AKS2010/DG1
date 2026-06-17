-- ============================================================================
-- eNFeNITE GRC Intelligence Platform - PostgreSQL Schema
-- Module: Risk & Controls
-- Sub-modules: Risk Register, Risk Assessment, Risk Heatmap, Treatment/Mitigation,
--              Control Library, Risk-Control Mapping, Control Testing,
--              Control Effectiveness, Incident/Loss/Exception Log
-- ============================================================================

-- ============================================================================
-- RISK REGISTER
-- ============================================================================

CREATE TABLE risks (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    entity_id               UUID NOT NULL REFERENCES entities(id),
    period_id               UUID REFERENCES financial_periods(id),
    
    -- Identification
    risk_code               VARCHAR(50) NOT NULL,        -- auto-generated: RSK-001
    risk_title              VARCHAR(500) NOT NULL,
    risk_category           VARCHAR(100) NOT NULL,       -- from master_configurations
    risk_type               risk_type NOT NULL,
    process                 VARCHAR(200),
    department              VARCHAR(200),
    location                VARCHAR(200),
    
    -- Description & Context
    description             TEXT,
    root_cause              TEXT,
    risk_event              TEXT,
    impact_description      TEXT,
    
    -- Ownership
    risk_owner_id           UUID NOT NULL REFERENCES users(id),
    risk_delegate_id        UUID REFERENCES users(id),
    
    -- Inherent Risk Assessment
    inherent_likelihood     INTEGER NOT NULL CHECK (inherent_likelihood BETWEEN 1 AND 5),
    inherent_impact         INTEGER NOT NULL CHECK (inherent_impact BETWEEN 1 AND 5),
    inherent_score          NUMERIC(5,2) GENERATED ALWAYS AS (inherent_likelihood * inherent_impact) STORED,
    
    -- Residual Risk Assessment
    residual_likelihood     INTEGER CHECK (residual_likelihood BETWEEN 1 AND 5),
    residual_impact         INTEGER CHECK (residual_impact BETWEEN 1 AND 5),
    residual_score          NUMERIC(5,2) GENERATED ALWAYS AS (residual_likelihood * residual_impact) STORED,
    
    -- Target Risk (Appetite)
    target_likelihood       INTEGER CHECK (target_likelihood BETWEEN 1 AND 5),
    target_impact           INTEGER CHECK (target_impact BETWEEN 1 AND 5),
    target_score            NUMERIC(5,2) GENERATED ALWAYS AS (target_likelihood * target_impact) STORED,
    
    -- Treatment
    treatment_strategy      treatment_strategy,
    target_date             DATE,
    
    -- Review
    review_frequency        frequency_type,
    last_review_date        DATE,
    next_review_date        DATE,
    
    -- Framework Reference
    framework_reference     VARCHAR(500),             -- e.g., 'ISO 27001 A.8.1', 'COSO ERM'
    
    -- Workflow
    status                  lifecycle_status NOT NULL DEFAULT 'draft',
    approved_by             UUID REFERENCES users(id),
    approved_at             TIMESTAMPTZ,
    
    -- Dynamic fields
    custom_attributes       JSONB DEFAULT '{}',
    tags                    TEXT[] DEFAULT '{}',
    
    -- Standard Audit Fields
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID NOT NULL REFERENCES users(id),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID REFERENCES users(id),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at              TIMESTAMPTZ,
    deleted_by              UUID REFERENCES users(id),
    version                 INTEGER NOT NULL DEFAULT 1,
    
    UNIQUE(tenant_id, entity_id, risk_code)
);

CREATE INDEX idx_risks_tenant_entity ON risks(tenant_id, entity_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_risks_owner ON risks(risk_owner_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_risks_status ON risks(tenant_id, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_risks_category ON risks(tenant_id, risk_category) WHERE is_deleted = FALSE;
CREATE INDEX idx_risks_type ON risks(tenant_id, risk_type) WHERE is_deleted = FALSE;
CREATE INDEX idx_risks_inherent_score ON risks(tenant_id, inherent_score DESC) WHERE is_deleted = FALSE;
CREATE INDEX idx_risks_residual_score ON risks(tenant_id, residual_score DESC) WHERE is_deleted = FALSE;
CREATE INDEX idx_risks_next_review ON risks(next_review_date) WHERE is_deleted = FALSE AND status = 'active';
CREATE INDEX idx_risks_custom_attrs ON risks USING GIN (custom_attributes) WHERE is_deleted = FALSE;
CREATE INDEX idx_risks_tags ON risks USING GIN (tags) WHERE is_deleted = FALSE;

-- ============================================================================
-- RISK ASSESSMENT HISTORY (point-in-time snapshots)
-- ============================================================================

CREATE TABLE risk_assessments (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    risk_id                 UUID NOT NULL REFERENCES risks(id),
    assessment_date         DATE NOT NULL,
    assessed_by             UUID NOT NULL REFERENCES users(id),
    
    inherent_likelihood     INTEGER NOT NULL CHECK (inherent_likelihood BETWEEN 1 AND 5),
    inherent_impact         INTEGER NOT NULL CHECK (inherent_impact BETWEEN 1 AND 5),
    inherent_score          NUMERIC(5,2) GENERATED ALWAYS AS (inherent_likelihood * inherent_impact) STORED,
    
    residual_likelihood     INTEGER CHECK (residual_likelihood BETWEEN 1 AND 5),
    residual_impact         INTEGER CHECK (residual_impact BETWEEN 1 AND 5),
    residual_score          NUMERIC(5,2) GENERATED ALWAYS AS (residual_likelihood * residual_impact) STORED,
    
    assessment_notes        TEXT,
    assessment_evidence     TEXT,
    
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID NOT NULL REFERENCES users(id)
);

CREATE INDEX idx_risk_assessments_risk ON risk_assessments(risk_id, assessment_date DESC);
CREATE INDEX idx_risk_assessments_tenant ON risk_assessments(tenant_id, assessment_date DESC);

-- ============================================================================
-- CONTROL LIBRARY
-- ============================================================================

CREATE TABLE controls (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    entity_id               UUID NOT NULL REFERENCES entities(id),
    
    -- Identification
    control_code            VARCHAR(50) NOT NULL,        -- auto-generated: CTL-001
    control_title           VARCHAR(500) NOT NULL,
    control_objective       TEXT,
    control_description     TEXT NOT NULL,
    
    -- Classification
    control_type            control_type NOT NULL,
    control_nature          control_nature NOT NULL,
    frequency               frequency_type NOT NULL,
    
    -- Ownership
    control_owner_id        UUID NOT NULL REFERENCES users(id),
    
    -- Evidence
    evidence_required       TEXT,
    evidence_description    TEXT,
    
    -- Linked processes & assertions
    linked_processes        TEXT[],
    linked_assertions       TEXT[],                   -- financial assertions or compliance clauses
    
    -- Effectiveness
    design_effectiveness    assessment_rating DEFAULT 'not_assessed',
    operating_effectiveness assessment_rating DEFAULT 'not_assessed',
    last_tested_date        DATE,
    next_test_due           DATE,
    
    -- Framework Reference
    framework_reference     VARCHAR(500),
    
    -- Workflow
    status                  lifecycle_status NOT NULL DEFAULT 'draft',
    approved_by             UUID REFERENCES users(id),
    approved_at             TIMESTAMPTZ,
    
    -- Dynamic fields
    custom_attributes       JSONB DEFAULT '{}',
    tags                    TEXT[] DEFAULT '{}',
    
    -- Standard Audit Fields
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID NOT NULL REFERENCES users(id),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID REFERENCES users(id),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at              TIMESTAMPTZ,
    deleted_by              UUID REFERENCES users(id),
    version                 INTEGER NOT NULL DEFAULT 1,
    
    UNIQUE(tenant_id, entity_id, control_code)
);

CREATE INDEX idx_controls_tenant_entity ON controls(tenant_id, entity_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_controls_owner ON controls(control_owner_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_controls_type ON controls(tenant_id, control_type) WHERE is_deleted = FALSE;
CREATE INDEX idx_controls_status ON controls(tenant_id, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_controls_next_test ON controls(next_test_due) WHERE is_deleted = FALSE AND status = 'active';
CREATE INDEX idx_controls_custom_attrs ON controls USING GIN (custom_attributes) WHERE is_deleted = FALSE;

-- ============================================================================
-- RISK-CONTROL MAPPING (Many-to-Many)
-- ============================================================================

CREATE TABLE risk_control_mappings (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    risk_id                 UUID NOT NULL REFERENCES risks(id),
    control_id              UUID NOT NULL REFERENCES controls(id),
    mapping_type            VARCHAR(50) DEFAULT 'primary',  -- 'primary', 'secondary', 'compensating'
    effectiveness_rating    assessment_rating DEFAULT 'not_assessed',
    notes                   TEXT,
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID NOT NULL REFERENCES users(id),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID REFERENCES users(id),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE(risk_id, control_id)
);

CREATE INDEX idx_risk_control_risk ON risk_control_mappings(risk_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_risk_control_control ON risk_control_mappings(control_id) WHERE is_deleted = FALSE;

-- ============================================================================
-- CONTROL TESTING
-- ============================================================================

CREATE TABLE control_tests (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    control_id              UUID NOT NULL REFERENCES controls(id),
    
    test_code               VARCHAR(50) NOT NULL,
    test_title              VARCHAR(500) NOT NULL,
    test_description        TEXT,
    test_procedure          TEXT,
    
    -- Execution
    test_date               DATE NOT NULL,
    tested_by               UUID NOT NULL REFERENCES users(id),
    reviewed_by             UUID REFERENCES users(id),
    
    -- Sample
    sample_size             INTEGER,
    population_size         INTEGER,
    exceptions_found        INTEGER DEFAULT 0,
    
    -- Results
    design_conclusion       assessment_rating,
    operating_conclusion    assessment_rating,
    overall_conclusion      assessment_rating NOT NULL DEFAULT 'not_assessed',
    conclusion_notes        TEXT,
    
    -- Workflow
    status                  lifecycle_status NOT NULL DEFAULT 'draft',
    
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID NOT NULL REFERENCES users(id),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID REFERENCES users(id),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_control_tests_control ON control_tests(control_id, test_date DESC) WHERE is_deleted = FALSE;
CREATE INDEX idx_control_tests_tenant ON control_tests(tenant_id, test_date DESC) WHERE is_deleted = FALSE;

-- ============================================================================
-- TREATMENT / MITIGATION PLANS
-- ============================================================================

CREATE TABLE treatment_plans (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    risk_id                 UUID NOT NULL REFERENCES risks(id),
    
    plan_code               VARCHAR(50) NOT NULL,
    plan_title              VARCHAR(500) NOT NULL,
    description             TEXT,
    strategy                treatment_strategy NOT NULL,
    
    -- Ownership & Timeline
    plan_owner_id           UUID NOT NULL REFERENCES users(id),
    start_date              DATE,
    target_date             DATE NOT NULL,
    completion_date         DATE,
    
    -- Expected outcome
    expected_residual_likelihood INTEGER CHECK (expected_residual_likelihood BETWEEN 1 AND 5),
    expected_residual_impact     INTEGER CHECK (expected_residual_impact BETWEEN 1 AND 5),
    
    -- Budget
    estimated_cost          NUMERIC(15,2),
    actual_cost             NUMERIC(15,2),
    currency                VARCHAR(10) DEFAULT 'INR',
    
    -- Progress
    progress_percent        INTEGER DEFAULT 0 CHECK (progress_percent BETWEEN 0 AND 100),
    status                  action_status NOT NULL DEFAULT 'open',
    
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID NOT NULL REFERENCES users(id),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID REFERENCES users(id),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_treatment_plans_risk ON treatment_plans(risk_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_treatment_plans_owner ON treatment_plans(plan_owner_id, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_treatment_plans_status ON treatment_plans(tenant_id, status) WHERE is_deleted = FALSE;

-- ============================================================================
-- INCIDENT / LOSS / EXCEPTION LOG
-- ============================================================================

CREATE TABLE incidents (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    entity_id               UUID NOT NULL REFERENCES entities(id),
    
    incident_code           VARCHAR(50) NOT NULL,
    incident_title          VARCHAR(500) NOT NULL,
    incident_type           VARCHAR(100) NOT NULL,    -- 'incident', 'loss_event', 'near_miss', 'exception', 'breach'
    category                VARCHAR(200),
    
    -- Details
    description             TEXT NOT NULL,
    root_cause              TEXT,
    impact_description      TEXT,
    
    -- Timeline
    occurred_at             TIMESTAMPTZ NOT NULL,
    detected_at             TIMESTAMPTZ,
    reported_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_at             TIMESTAMPTZ,
    
    -- Severity & Impact
    severity                finding_severity NOT NULL,
    financial_impact        NUMERIC(15,2),
    currency                VARCHAR(10) DEFAULT 'INR',
    people_affected         INTEGER,
    
    -- Ownership
    reported_by             UUID NOT NULL REFERENCES users(id),
    assigned_to             UUID REFERENCES users(id),
    
    -- Linked objects
    linked_risk_id          UUID REFERENCES risks(id),
    linked_control_id       UUID REFERENCES controls(id),
    
    -- Resolution
    resolution_notes        TEXT,
    corrective_action       TEXT,
    preventive_action       TEXT,
    
    -- Workflow
    status                  lifecycle_status NOT NULL DEFAULT 'draft',
    
    custom_attributes       JSONB DEFAULT '{}',
    tags                    TEXT[] DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID NOT NULL REFERENCES users(id),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID REFERENCES users(id),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE(tenant_id, entity_id, incident_code)
);

CREATE INDEX idx_incidents_tenant_entity ON incidents(tenant_id, entity_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_incidents_severity ON incidents(tenant_id, severity) WHERE is_deleted = FALSE;
CREATE INDEX idx_incidents_status ON incidents(tenant_id, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_incidents_occurred ON incidents(occurred_at DESC) WHERE is_deleted = FALSE;
CREATE INDEX idx_incidents_linked_risk ON incidents(linked_risk_id) WHERE linked_risk_id IS NOT NULL AND is_deleted = FALSE;
