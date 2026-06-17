-- ============================================================================
-- eNFeNITE GRC Intelligence Platform - PostgreSQL Schema
-- Module: Training & Awareness (Basic Phase 1)
-- ============================================================================

-- ============================================================================
-- TRAINING COURSES / PROGRAMS
-- ============================================================================

CREATE TABLE training_courses (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    
    course_code             VARCHAR(50) NOT NULL,
    course_title            VARCHAR(500) NOT NULL,
    description             TEXT,
    
    -- Classification
    category                VARCHAR(200) NOT NULL,    -- 'compliance', 'security_awareness', 'risk_management', 'policy', 'technical', 'onboarding'
    target_audience         VARCHAR(500),             -- description of who should take it
    
    -- Content
    content_type            VARCHAR(50) NOT NULL DEFAULT 'document', -- 'document', 'video', 'scorm', 'quiz', 'external_link'
    content_url             VARCHAR(1000),
    duration_minutes        INTEGER,
    
    -- Linked compliance
    linked_obligation_id    UUID REFERENCES compliance_obligations(id),
    linked_framework_id     UUID REFERENCES frameworks(id),
    
    -- Recurrence
    is_mandatory            BOOLEAN NOT NULL DEFAULT FALSE,
    is_recurring            BOOLEAN NOT NULL DEFAULT FALSE,
    recurrence_frequency    frequency_type,
    
    -- Validity
    valid_from              DATE,
    valid_to                DATE,
    passing_score           NUMERIC(5,2),             -- minimum score to pass (if quiz)
    
    -- Status
    status                  lifecycle_status NOT NULL DEFAULT 'draft',
    
    custom_attributes       JSONB DEFAULT '{}',
    tags                    TEXT[] DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID NOT NULL REFERENCES users(id),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID REFERENCES users(id),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE(tenant_id, course_code)
);

CREATE INDEX idx_training_courses_tenant ON training_courses(tenant_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_training_courses_category ON training_courses(tenant_id, category) WHERE is_deleted = FALSE;
CREATE INDEX idx_training_courses_mandatory ON training_courses(tenant_id, is_mandatory) WHERE is_mandatory = TRUE AND is_deleted = FALSE;

-- ============================================================================
-- TRAINING ASSIGNMENTS (Who needs to complete what)
-- ============================================================================

CREATE TABLE training_assignments (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    course_id               UUID NOT NULL REFERENCES training_courses(id),
    user_id                 UUID NOT NULL REFERENCES users(id),
    
    -- Assignment details
    assigned_by             UUID REFERENCES users(id),
    assigned_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    due_date                DATE NOT NULL,
    
    -- Completion
    status                  VARCHAR(50) NOT NULL DEFAULT 'assigned', -- 'assigned', 'in_progress', 'completed', 'overdue', 'exempted'
    started_at              TIMESTAMPTZ,
    completed_at            TIMESTAMPTZ,
    score                   NUMERIC(5,2),
    is_passed               BOOLEAN,
    attempts                INTEGER DEFAULT 0,
    
    -- Certificate
    certificate_id          VARCHAR(200),
    
    -- Reminders
    reminder_count          INTEGER DEFAULT 0,
    last_reminder_sent      TIMESTAMPTZ,
    
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID REFERENCES users(id),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE(course_id, user_id, assigned_at)
);

CREATE INDEX idx_training_assignments_user ON training_assignments(user_id, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_training_assignments_course ON training_assignments(course_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_training_assignments_due ON training_assignments(due_date) WHERE status NOT IN ('completed', 'exempted') AND is_deleted = FALSE;
CREATE INDEX idx_training_assignments_tenant ON training_assignments(tenant_id, status) WHERE is_deleted = FALSE;
