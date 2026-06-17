-- ============================================================================
-- eNFeNITE GRC Intelligence Platform - PostgreSQL Schema
-- Module: Assessments & Audit
-- Sub-modules: Assessment/Audit Plan, Framework Library, Questionnaire/Test Sheets,
--              Findings & Observations, Query/PBC Tracker, Issue Closure Tracker
-- ============================================================================

-- ============================================================================
-- FRAMEWORK LIBRARY
-- ============================================================================

CREATE TABLE frameworks (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    
    framework_code          VARCHAR(100) NOT NULL,
    framework_name          VARCHAR(500) NOT NULL,
    framework_version       VARCHAR(50),
    framework_type          VARCHAR(100) NOT NULL,    -- 'regulatory', 'standard', 'internal', 'industry'
    category                VARCHAR(200),             -- 'IT', 'financial', 'privacy', 'quality', 'compliance'
    
    description             TEXT,
    issuing_body            VARCHAR(300),             -- e.g., 'ISO', 'SEBI', 'MCA', 'CERT-IN'
    effective_date          DATE,
    
    -- Structure
    total_domains           INTEGER DEFAULT 0,
    total_controls          INTEGER DEFAULT 0,
    
    is_system_framework     BOOLEAN NOT NULL DEFAULT FALSE,  -- pre-loaded frameworks
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID,
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID,
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE(tenant_id, framework_code, framework_version)
);

CREATE INDEX idx_frameworks_tenant ON frameworks(tenant_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_frameworks_type ON frameworks(tenant_id, framework_type) WHERE is_deleted = FALSE;

-- Framework domains/sections (hierarchical)
CREATE TABLE framework_domains (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    framework_id            UUID NOT NULL REFERENCES frameworks(id),
    parent_domain_id        UUID REFERENCES framework_domains(id),
    
    domain_code             VARCHAR(100) NOT NULL,
    domain_name             VARCHAR(500) NOT NULL,
    description             TEXT,
    display_order           INTEGER NOT NULL DEFAULT 0,
    level                   INTEGER NOT NULL DEFAULT 1,    -- hierarchy depth
    
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID,
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE(framework_id, domain_code)
);

CREATE INDEX idx_framework_domains_fw ON framework_domains(framework_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_framework_domains_parent ON framework_domains(parent_domain_id) WHERE is_deleted = FALSE;

-- Framework requirements/controls
CREATE TABLE framework_requirements (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    framework_id            UUID NOT NULL REFERENCES frameworks(id),
    domain_id               UUID NOT NULL REFERENCES framework_domains(id),
    
    requirement_code        VARCHAR(100) NOT NULL,
    requirement_title       VARCHAR(500) NOT NULL,
    requirement_description TEXT,
    guidance_notes          TEXT,
    display_order           INTEGER NOT NULL DEFAULT 0,
    
    is_mandatory            BOOLEAN NOT NULL DEFAULT TRUE,
    
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID,
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE(framework_id, requirement_code)
);

CREATE INDEX idx_framework_reqs_fw ON framework_requirements(framework_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_framework_reqs_domain ON framework_requirements(domain_id) WHERE is_deleted = FALSE;

-- ============================================================================
-- ASSESSMENT / AUDIT PLAN
-- ============================================================================

CREATE TABLE assessment_plans (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    entity_id               UUID NOT NULL REFERENCES entities(id),
    period_id               UUID REFERENCES financial_periods(id),
    
    plan_code               VARCHAR(50) NOT NULL,
    plan_title              VARCHAR(500) NOT NULL,
    plan_type               VARCHAR(100) NOT NULL,    -- 'internal_audit', 'it_audit', 'compliance_review', 'financial_audit', 'cyber_assessment', 'framework_assessment'
    
    -- Scope
    description             TEXT,
    scope                   TEXT,
    objectives              TEXT,
    methodology             TEXT,
    
    -- Framework
    framework_id            UUID REFERENCES frameworks(id),
    
    -- Timeline
    planned_start_date      DATE,
    planned_end_date        DATE,
    actual_start_date       DATE,
    actual_end_date         DATE,
    
    -- Team
    engagement_partner_id   UUID REFERENCES users(id),
    engagement_manager_id   UUID REFERENCES users(id),
    lead_auditor_id         UUID REFERENCES users(id),
    
    -- Budget
    budgeted_hours          NUMERIC(8,2),
    actual_hours            NUMERIC(8,2),
    
    -- Workflow
    status                  lifecycle_status NOT NULL DEFAULT 'draft',
    approved_by             UUID REFERENCES users(id),
    approved_at             TIMESTAMPTZ,
    
    -- Results Summary
    overall_rating          assessment_rating DEFAULT 'not_assessed',
    summary_conclusion      TEXT,
    
    custom_attributes       JSONB DEFAULT '{}',
    tags                    TEXT[] DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID NOT NULL REFERENCES users(id),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID REFERENCES users(id),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE(tenant_id, entity_id, plan_code)
);

CREATE INDEX idx_assessment_plans_tenant ON assessment_plans(tenant_id, entity_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_assessment_plans_status ON assessment_plans(tenant_id, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_assessment_plans_type ON assessment_plans(tenant_id, plan_type) WHERE is_deleted = FALSE;
CREATE INDEX idx_assessment_plans_framework ON assessment_plans(framework_id) WHERE framework_id IS NOT NULL AND is_deleted = FALSE;

-- Assessment team members
CREATE TABLE assessment_team_members (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    assessment_plan_id      UUID NOT NULL REFERENCES assessment_plans(id),
    user_id                 UUID NOT NULL REFERENCES users(id),
    role_in_assessment      VARCHAR(100) NOT NULL,    -- 'partner', 'manager', 'lead', 'team_member', 'specialist', 'reviewer'
    budgeted_hours          NUMERIC(8,2),
    actual_hours            NUMERIC(8,2),
    assigned_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    assigned_by             UUID,
    UNIQUE(assessment_plan_id, user_id)
);

-- ============================================================================
-- QUESTIONNAIRE / TEST SHEETS
-- ============================================================================

CREATE TABLE questionnaires (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    assessment_plan_id      UUID REFERENCES assessment_plans(id),
    framework_id            UUID REFERENCES frameworks(id),
    
    questionnaire_code      VARCHAR(50) NOT NULL,
    questionnaire_title     VARCHAR(500) NOT NULL,
    description             TEXT,
    questionnaire_type      VARCHAR(100) NOT NULL,    -- 'checklist', 'test_sheet', 'self_assessment', 'audit_program', 'walkthrough'
    
    -- Scoring
    scoring_method          VARCHAR(50) NOT NULL DEFAULT 'yes_no_na', -- 'yes_no_na', 'rating_scale', 'percentage', 'maturity_level'
    max_score               NUMERIC(8,2),
    passing_score           NUMERIC(8,2),
    
    status                  lifecycle_status NOT NULL DEFAULT 'draft',
    total_questions         INTEGER DEFAULT 0,
    
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID NOT NULL REFERENCES users(id),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID REFERENCES users(id),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE(tenant_id, questionnaire_code)
);

CREATE INDEX idx_questionnaires_tenant ON questionnaires(tenant_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_questionnaires_plan ON questionnaires(assessment_plan_id) WHERE assessment_plan_id IS NOT NULL AND is_deleted = FALSE;

-- Questions within a questionnaire
CREATE TABLE questions (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    questionnaire_id        UUID NOT NULL REFERENCES questionnaires(id),
    framework_requirement_id UUID REFERENCES framework_requirements(id),
    
    question_code           VARCHAR(50) NOT NULL,
    question_text           TEXT NOT NULL,
    guidance_notes          TEXT,
    section                 VARCHAR(200),
    display_order           INTEGER NOT NULL DEFAULT 0,
    
    -- Scoring
    weight                  NUMERIC(5,2) DEFAULT 1.0,
    is_mandatory            BOOLEAN NOT NULL DEFAULT TRUE,
    is_critical             BOOLEAN NOT NULL DEFAULT FALSE,  -- critical failure if non-compliant
    
    -- Expected response
    expected_response       VARCHAR(100),             -- expected answer for auto-scoring
    evidence_required       BOOLEAN NOT NULL DEFAULT FALSE,
    
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID,
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE(questionnaire_id, question_code)
);

CREATE INDEX idx_questions_questionnaire ON questions(questionnaire_id, display_order) WHERE is_deleted = FALSE;

-- ============================================================================
-- ASSESSMENT RESPONSES (filled during execution)
-- ============================================================================

CREATE TABLE assessment_responses (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    entity_id               UUID NOT NULL REFERENCES entities(id),
    assessment_plan_id      UUID NOT NULL REFERENCES assessment_plans(id),
    questionnaire_id        UUID NOT NULL REFERENCES questionnaires(id),
    question_id             UUID NOT NULL REFERENCES questions(id),
    
    -- Response
    response_value          VARCHAR(100),             -- 'yes', 'no', 'na', '3', 'partial'
    response_score          NUMERIC(5,2),
    response_notes          TEXT,
    
    -- Evidence
    evidence_provided       BOOLEAN DEFAULT FALSE,
    evidence_reference      TEXT,                     -- reference to document/evidence
    
    -- Reviewer
    responded_by            UUID NOT NULL REFERENCES users(id),
    responded_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    reviewed_by             UUID REFERENCES users(id),
    reviewed_at             TIMESTAMPTZ,
    review_notes            TEXT,
    
    -- Finding link
    finding_id              UUID,                     -- populated later if finding is raised
    
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE(assessment_plan_id, questionnaire_id, question_id, entity_id)
);

CREATE INDEX idx_responses_plan ON assessment_responses(assessment_plan_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_responses_questionnaire ON assessment_responses(questionnaire_id) WHERE is_deleted = FALSE;

-- ============================================================================
-- FINDINGS & OBSERVATIONS
-- ============================================================================

CREATE TABLE findings (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    entity_id               UUID NOT NULL REFERENCES entities(id),
    assessment_plan_id      UUID REFERENCES assessment_plans(id),
    
    finding_code            VARCHAR(50) NOT NULL,
    finding_title           VARCHAR(500) NOT NULL,
    finding_type            VARCHAR(100) NOT NULL,    -- 'finding', 'observation', 'recommendation', 'non_conformity', 'exception'
    
    -- Details
    condition               TEXT NOT NULL,            -- what was found
    criteria                TEXT,                     -- what should be
    cause                   TEXT,                     -- why it happened
    effect                  TEXT,                     -- impact/consequence
    recommendation          TEXT,
    management_response     TEXT,
    
    -- Classification
    severity                finding_severity NOT NULL,
    category                VARCHAR(200),
    
    -- Linked objects
    linked_risk_id          UUID REFERENCES risks(id),
    linked_control_id       UUID REFERENCES controls(id),
    linked_framework_req_id UUID REFERENCES framework_requirements(id),
    
    -- Ownership
    raised_by               UUID NOT NULL REFERENCES users(id),
    assigned_to             UUID REFERENCES users(id),
    
    -- Timeline
    identified_date         DATE NOT NULL,
    due_date                DATE,
    closed_date             DATE,
    
    -- Workflow
    status                  lifecycle_status NOT NULL DEFAULT 'draft',
    
    -- Repeat indicator
    is_repeat_finding       BOOLEAN NOT NULL DEFAULT FALSE,
    previous_finding_id     UUID REFERENCES findings(id),
    
    custom_attributes       JSONB DEFAULT '{}',
    tags                    TEXT[] DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID NOT NULL REFERENCES users(id),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID REFERENCES users(id),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE(tenant_id, entity_id, finding_code)
);

CREATE INDEX idx_findings_tenant_entity ON findings(tenant_id, entity_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_findings_plan ON findings(assessment_plan_id) WHERE assessment_plan_id IS NOT NULL AND is_deleted = FALSE;
CREATE INDEX idx_findings_severity ON findings(tenant_id, severity) WHERE is_deleted = FALSE;
CREATE INDEX idx_findings_status ON findings(tenant_id, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_findings_assigned ON findings(assigned_to, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_findings_due_date ON findings(due_date) WHERE is_deleted = FALSE AND status != 'closed';

-- ============================================================================
-- QUERY MANAGEMENT / PBC TRACKER
-- ============================================================================

CREATE TABLE pbc_queries (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    entity_id               UUID NOT NULL REFERENCES entities(id),
    assessment_plan_id      UUID NOT NULL REFERENCES assessment_plans(id),
    
    query_code              VARCHAR(50) NOT NULL,
    query_title             VARCHAR(500) NOT NULL,
    query_description       TEXT NOT NULL,
    category                VARCHAR(200),
    
    -- Assignment
    requested_by            UUID NOT NULL REFERENCES users(id),
    assigned_to             UUID NOT NULL REFERENCES users(id),
    
    -- Timeline
    requested_date          DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date                DATE NOT NULL,
    responded_date          DATE,
    closed_date             DATE,
    
    -- Response
    response_text           TEXT,
    
    -- Priority & Status
    priority                priority_level NOT NULL DEFAULT 'medium',
    status                  action_status NOT NULL DEFAULT 'open',
    
    -- Reminders
    reminder_count          INTEGER DEFAULT 0,
    last_reminder_sent      TIMESTAMPTZ,
    
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID NOT NULL REFERENCES users(id),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID REFERENCES users(id),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE(tenant_id, assessment_plan_id, query_code)
);

CREATE INDEX idx_pbc_queries_plan ON pbc_queries(assessment_plan_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_pbc_queries_assigned ON pbc_queries(assigned_to, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_pbc_queries_due ON pbc_queries(due_date) WHERE is_deleted = FALSE AND status NOT IN ('completed', 'cancelled');
