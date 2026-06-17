-- ============================================================================
-- eNFeNITE GRC Intelligence Platform - PostgreSQL Schema
-- Module: Alerts, Actions & Reports
-- Cross-platform execution layer for action management, alerts, and reporting
-- ============================================================================

-- ============================================================================
-- ACTIONS (Universal action items across all modules)
-- ============================================================================

CREATE TABLE actions (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    entity_id               UUID NOT NULL REFERENCES entities(id),
    
    action_code             VARCHAR(50) NOT NULL,
    action_title            VARCHAR(500) NOT NULL,
    description             TEXT,
    
    -- Source
    source_module           VARCHAR(100) NOT NULL,    -- 'risk', 'control', 'finding', 'compliance', 'finance', 'incident', 'audit'
    source_object_type      VARCHAR(100) NOT NULL,
    source_object_id        UUID NOT NULL,
    
    -- Classification
    action_type             VARCHAR(100),             -- 'corrective', 'preventive', 'improvement', 'follow_up', 'remediation'
    priority                priority_level NOT NULL DEFAULT 'medium',
    
    -- Ownership
    owner_id                UUID NOT NULL REFERENCES users(id),
    delegate_id             UUID REFERENCES users(id),
    assigned_by             UUID REFERENCES users(id),
    
    -- Timeline
    due_date                DATE NOT NULL,
    original_due_date       DATE,
    extended_count          INTEGER DEFAULT 0,
    extension_reason        TEXT,
    start_date              DATE,
    completion_date         DATE,
    
    -- Progress
    progress_percent        INTEGER DEFAULT 0 CHECK (progress_percent BETWEEN 0 AND 100),
    status                  action_status NOT NULL DEFAULT 'open',
    
    -- Resolution
    resolution_notes        TEXT,
    verified_by             UUID REFERENCES users(id),
    verified_at             TIMESTAMPTZ,
    
    -- Escalation
    is_escalated            BOOLEAN NOT NULL DEFAULT FALSE,
    escalated_to            UUID REFERENCES users(id),
    escalated_at            TIMESTAMPTZ,
    escalation_level        INTEGER DEFAULT 0,
    
    -- Reminders
    reminder_frequency      frequency_type DEFAULT 'weekly',
    next_reminder_date      DATE,
    reminder_count          INTEGER DEFAULT 0,
    last_reminder_sent      TIMESTAMPTZ,
    
    custom_attributes       JSONB DEFAULT '{}',
    tags                    TEXT[] DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID NOT NULL REFERENCES users(id),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID REFERENCES users(id),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE(tenant_id, entity_id, action_code)
);

CREATE INDEX idx_actions_tenant_entity ON actions(tenant_id, entity_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_actions_owner ON actions(owner_id, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_actions_status ON actions(tenant_id, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_actions_priority ON actions(tenant_id, priority) WHERE is_deleted = FALSE AND status NOT IN ('completed', 'cancelled');
CREATE INDEX idx_actions_due_date ON actions(due_date) WHERE is_deleted = FALSE AND status NOT IN ('completed', 'cancelled');
CREATE INDEX idx_actions_source ON actions(source_object_type, source_object_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_actions_overdue ON actions(tenant_id, due_date, status) WHERE is_deleted = FALSE AND status = 'overdue';
CREATE INDEX idx_actions_escalated ON actions(tenant_id, is_escalated) WHERE is_escalated = TRUE AND is_deleted = FALSE;

-- Action comments/updates
CREATE TABLE action_comments (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    action_id               UUID NOT NULL REFERENCES actions(id),
    comment_text            TEXT NOT NULL,
    comment_type            VARCHAR(50) DEFAULT 'update', -- 'update', 'escalation', 'extension_request', 'closure_note', 'system'
    commented_by            UUID NOT NULL REFERENCES users(id),
    commented_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_action_comments_action ON action_comments(action_id, commented_at DESC) WHERE is_deleted = FALSE;

-- ============================================================================
-- ALERTS (System-generated and manual alerts)
-- ============================================================================

CREATE TABLE alerts (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    entity_id               UUID REFERENCES entities(id),
    
    alert_code              VARCHAR(100),
    alert_title             VARCHAR(500) NOT NULL,
    alert_message           TEXT NOT NULL,
    alert_type              alert_type NOT NULL,
    
    -- Source
    source_module           VARCHAR(100),
    source_object_type      VARCHAR(100),
    source_object_id        UUID,
    
    -- Severity & Priority
    severity                finding_severity NOT NULL DEFAULT 'medium',
    priority                priority_level NOT NULL DEFAULT 'medium',
    
    -- Targeting
    target_user_ids         UUID[] DEFAULT '{}',      -- specific users to notify
    target_role_ids         UUID[] DEFAULT '{}',      -- roles to notify
    
    -- Status
    is_read                 BOOLEAN NOT NULL DEFAULT FALSE,
    is_acknowledged         BOOLEAN NOT NULL DEFAULT FALSE,
    acknowledged_by         UUID REFERENCES users(id),
    acknowledged_at         TIMESTAMPTZ,
    
    is_resolved             BOOLEAN NOT NULL DEFAULT FALSE,
    resolved_by             UUID REFERENCES users(id),
    resolved_at             TIMESTAMPTZ,
    resolution_notes        TEXT,
    
    -- Notification
    notification_sent       BOOLEAN NOT NULL DEFAULT FALSE,
    notification_sent_at    TIMESTAMPTZ,
    notification_channel    VARCHAR(50),              -- 'email', 'in_app', 'sms', 'push'
    
    -- Auto-dismissal
    expires_at              TIMESTAMPTZ,
    
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID,                     -- NULL for system-generated
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_alerts_tenant ON alerts(tenant_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_alerts_unread ON alerts(tenant_id, is_read) WHERE is_read = FALSE AND is_deleted = FALSE;
CREATE INDEX idx_alerts_type ON alerts(tenant_id, alert_type) WHERE is_deleted = FALSE;
CREATE INDEX idx_alerts_severity ON alerts(tenant_id, severity) WHERE is_deleted = FALSE AND is_resolved = FALSE;
CREATE INDEX idx_alerts_target_users ON alerts USING GIN (target_user_ids) WHERE is_deleted = FALSE;
CREATE INDEX idx_alerts_source ON alerts(source_object_type, source_object_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_alerts_created ON alerts(tenant_id, created_at DESC) WHERE is_deleted = FALSE;

-- Per-user alert read status (for multi-target alerts)
CREATE TABLE alert_user_status (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alert_id               UUID NOT NULL REFERENCES alerts(id),
    user_id                UUID NOT NULL REFERENCES users(id),
    is_read                BOOLEAN NOT NULL DEFAULT FALSE,
    read_at                TIMESTAMPTZ,
    is_dismissed           BOOLEAN NOT NULL DEFAULT FALSE,
    dismissed_at           TIMESTAMPTZ,
    UNIQUE(alert_id, user_id)
);

CREATE INDEX idx_alert_user_status_user ON alert_user_status(user_id, is_read) WHERE is_read = FALSE;

-- ============================================================================
-- ALERT RULES (Configurable thresholds for auto-alert generation)
-- ============================================================================

CREATE TABLE alert_rules (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    
    rule_name               VARCHAR(300) NOT NULL,
    rule_description        TEXT,
    
    -- Trigger conditions
    source_module           VARCHAR(100) NOT NULL,
    trigger_event           VARCHAR(100) NOT NULL,    -- 'due_date_approaching', 'threshold_breach', 'status_change', 'overdue', 'anomaly_detected'
    condition_config        JSONB NOT NULL,           -- flexible condition definition
    
    -- Alert configuration
    alert_type              alert_type NOT NULL,
    severity                finding_severity NOT NULL DEFAULT 'medium',
    alert_message_template  TEXT NOT NULL,            -- supports {{placeholders}}
    
    -- Targeting
    notify_owner            BOOLEAN NOT NULL DEFAULT TRUE,
    notify_roles            UUID[] DEFAULT '{}',
    notify_users            UUID[] DEFAULT '{}',
    escalation_after_days   INTEGER,
    escalation_to           UUID REFERENCES users(id),
    
    -- Schedule
    evaluation_frequency    frequency_type NOT NULL DEFAULT 'daily',
    last_evaluated_at       TIMESTAMPTZ,
    
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID NOT NULL REFERENCES users(id),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID REFERENCES users(id),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_alert_rules_tenant ON alert_rules(tenant_id) WHERE is_active = TRUE AND is_deleted = FALSE;

-- ============================================================================
-- REPORTS (Report definitions and generated report instances)
-- ============================================================================

CREATE TABLE report_definitions (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    
    report_code             VARCHAR(100) NOT NULL,
    report_name             VARCHAR(500) NOT NULL,
    description             TEXT,
    
    report_category         VARCHAR(100) NOT NULL,    -- 'risk', 'control', 'audit', 'compliance', 'finance', 'action', 'dashboard', 'executive'
    report_format           VARCHAR(50) NOT NULL DEFAULT 'pdf', -- 'pdf', 'xlsx', 'csv', 'html'
    
    -- Template
    template_config         JSONB NOT NULL,           -- report layout, filters, columns, grouping
    default_filters         JSONB DEFAULT '{}',
    
    -- Scheduling
    is_scheduled            BOOLEAN NOT NULL DEFAULT FALSE,
    schedule_frequency      frequency_type,
    schedule_recipients     UUID[] DEFAULT '{}',
    last_generated_at       TIMESTAMPTZ,
    next_generation_at      TIMESTAMPTZ,
    
    is_system_report        BOOLEAN NOT NULL DEFAULT FALSE,
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID,
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID,
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE(tenant_id, report_code)
);

CREATE INDEX idx_report_definitions_tenant ON report_definitions(tenant_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_report_definitions_category ON report_definitions(tenant_id, report_category) WHERE is_deleted = FALSE;

-- Generated report instances
CREATE TABLE report_instances (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    entity_id               UUID REFERENCES entities(id),
    report_definition_id    UUID NOT NULL REFERENCES report_definitions(id),
    
    -- Parameters used
    filters_applied         JSONB DEFAULT '{}',
    period_id               UUID REFERENCES financial_periods(id),
    
    -- Output
    file_name               VARCHAR(500),
    file_size_bytes         BIGINT,
    storage_path            VARCHAR(1000),
    file_format             VARCHAR(50),
    
    -- Status
    status                  VARCHAR(50) NOT NULL DEFAULT 'generating', -- 'generating', 'completed', 'failed', 'expired'
    error_message           TEXT,
    
    generated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    generated_by            UUID NOT NULL REFERENCES users(id),
    expires_at              TIMESTAMPTZ,              -- auto-cleanup
    download_count          INTEGER DEFAULT 0,
    last_downloaded_at      TIMESTAMPTZ
);

CREATE INDEX idx_report_instances_tenant ON report_instances(tenant_id, generated_at DESC);
CREATE INDEX idx_report_instances_definition ON report_instances(report_definition_id, generated_at DESC);
CREATE INDEX idx_report_instances_user ON report_instances(generated_by, generated_at DESC);
