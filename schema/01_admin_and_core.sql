-- ============================================================================
-- eNFeNITE GRC Intelligence Platform - PostgreSQL Schema
-- Module: Admin & Core Platform (Multi-Tenant, RBAC, Entity Management)
-- ============================================================================

-- ============================================================================
-- TENANT / CLIENT MANAGEMENT
-- ============================================================================

CREATE TABLE tenants (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_code         VARCHAR(50) NOT NULL UNIQUE,
    tenant_name         VARCHAR(255) NOT NULL,
    deployment_model    deployment_model NOT NULL DEFAULT 'saas_shared',
    subscription_plan   VARCHAR(100),
    subscription_start  DATE,
    subscription_end    DATE,
    max_users           INTEGER DEFAULT 50,
    max_entities        INTEGER DEFAULT 10,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    settings            JSONB DEFAULT '{}',          -- tenant-level config overrides
    custom_attributes   JSONB DEFAULT '{}',          -- dynamic tenant metadata
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID,
    modified_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by         UUID,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at          TIMESTAMPTZ
);

CREATE INDEX idx_tenants_code ON tenants(tenant_code) WHERE is_deleted = FALSE;
CREATE INDEX idx_tenants_active ON tenants(is_active) WHERE is_deleted = FALSE;

-- ============================================================================
-- PLATFORM USERS (Cross-Tenant Super Admins who manage tenants)
-- ============================================================================

CREATE TABLE platform_users (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email               VARCHAR(255) NOT NULL UNIQUE,
    password_hash       VARCHAR(512),                -- NULL if SSO/LDAP only
    first_name          VARCHAR(100) NOT NULL,
    last_name           VARCHAR(100),
    display_name        VARCHAR(200),
    phone               VARCHAR(50),
    designation         VARCHAR(150),
    platform_role       VARCHAR(50) NOT NULL DEFAULT 'platform_admin', -- 'super_admin', 'platform_admin', 'support', 'billing'
    auth_provider       VARCHAR(50) NOT NULL DEFAULT 'local',
    external_id         VARCHAR(255),
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    is_locked           BOOLEAN NOT NULL DEFAULT FALSE,
    locked_at           TIMESTAMPTZ,
    failed_login_count  INTEGER NOT NULL DEFAULT 0,
    last_login_at       TIMESTAMPTZ,
    password_changed_at TIMESTAMPTZ,
    must_change_password BOOLEAN NOT NULL DEFAULT FALSE,
    mfa_enabled         BOOLEAN NOT NULL DEFAULT TRUE,   -- enforced for platform users
    mfa_secret          VARCHAR(512),
    avatar_url          VARCHAR(500),
    preferences         JSONB DEFAULT '{}',
    custom_attributes   JSONB DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID REFERENCES platform_users(id),
    modified_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by         UUID REFERENCES platform_users(id),
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at          TIMESTAMPTZ
);

CREATE INDEX idx_platform_users_email ON platform_users(email) WHERE is_deleted = FALSE;
CREATE INDEX idx_platform_users_active ON platform_users(is_active) WHERE is_deleted = FALSE;
CREATE INDEX idx_platform_users_role ON platform_users(platform_role) WHERE is_deleted = FALSE;

-- Maps which tenants a platform user is assigned to manage (NULL row = all tenants)
CREATE TABLE platform_user_tenant_access (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform_user_id    UUID NOT NULL REFERENCES platform_users(id),
    tenant_id           UUID REFERENCES tenants(id),    -- NULL = global access to all tenants
    access_level        VARCHAR(50) NOT NULL DEFAULT 'full', -- 'full', 'read_only', 'support'
    granted_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    granted_by          UUID REFERENCES platform_users(id),
    expires_at          TIMESTAMPTZ,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE(platform_user_id, tenant_id)
);

CREATE INDEX idx_platform_user_tenant_access_user ON platform_user_tenant_access(platform_user_id) WHERE is_active = TRUE;
CREATE INDEX idx_platform_user_tenant_access_tenant ON platform_user_tenant_access(tenant_id) WHERE is_active = TRUE;

-- ============================================================================
-- ENTITY MANAGEMENT (Business Units / Legal Entities within a Tenant)
-- ============================================================================

CREATE TABLE entities (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id),
    entity_code         VARCHAR(50) NOT NULL,
    entity_name         VARCHAR(255) NOT NULL,
    entity_type         VARCHAR(100),               -- e.g., 'holding', 'subsidiary', 'branch', 'division'
    parent_entity_id    UUID REFERENCES entities(id),
    country             VARCHAR(100),
    currency            VARCHAR(10) DEFAULT 'INR',
    timezone            VARCHAR(50) DEFAULT 'Asia/Kolkata',
    industry            VARCHAR(100),
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    custom_attributes   JSONB DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID,
    modified_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by         UUID,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at          TIMESTAMPTZ,
    UNIQUE(tenant_id, entity_code)
);

CREATE INDEX idx_entities_tenant ON entities(tenant_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_entities_parent ON entities(parent_entity_id) WHERE is_deleted = FALSE;

-- ============================================================================
-- FINANCIAL PERIOD MANAGEMENT
-- ============================================================================

CREATE TABLE financial_periods (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id),
    entity_id           UUID REFERENCES entities(id),
    period_name         VARCHAR(100) NOT NULL,       -- e.g., 'FY 2025-26'
    period_type         VARCHAR(50) NOT NULL,        -- 'annual', 'quarterly', 'monthly'
    start_date          DATE NOT NULL,
    end_date            DATE NOT NULL,
    is_current          BOOLEAN NOT NULL DEFAULT FALSE,
    is_locked           BOOLEAN NOT NULL DEFAULT FALSE,
    custom_attributes   JSONB DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID,
    modified_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by         UUID,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_financial_periods_tenant ON financial_periods(tenant_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_financial_periods_current ON financial_periods(tenant_id, is_current) WHERE is_deleted = FALSE;

-- ============================================================================
-- USER MANAGEMENT
-- ============================================================================

CREATE TABLE users (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id),
    email               VARCHAR(255) NOT NULL,
    password_hash       VARCHAR(512),                -- NULL if SSO/LDAP only
    first_name          VARCHAR(100) NOT NULL,
    last_name           VARCHAR(100),
    display_name        VARCHAR(200),
    phone               VARCHAR(50),
    designation         VARCHAR(150),
    department          VARCHAR(150),
    auth_provider       VARCHAR(50) NOT NULL DEFAULT 'local', -- 'local', 'ldap', 'saml', 'oauth2'
    external_id         VARCHAR(255),                -- LDAP DN or SAML NameID
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    is_locked           BOOLEAN NOT NULL DEFAULT FALSE,
    locked_at           TIMESTAMPTZ,
    failed_login_count  INTEGER NOT NULL DEFAULT 0,
    last_login_at       TIMESTAMPTZ,
    password_changed_at TIMESTAMPTZ,
    must_change_password BOOLEAN NOT NULL DEFAULT FALSE,
    mfa_enabled         BOOLEAN NOT NULL DEFAULT FALSE,
    mfa_secret          VARCHAR(512),                -- encrypted TOTP secret
    avatar_url          VARCHAR(500),
    preferences         JSONB DEFAULT '{}',          -- UI preferences
    custom_attributes   JSONB DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID,
    modified_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by         UUID,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at          TIMESTAMPTZ,
    UNIQUE(tenant_id, email)
);

CREATE INDEX idx_users_tenant ON users(tenant_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_users_email ON users(email) WHERE is_deleted = FALSE;
CREATE INDEX idx_users_auth_provider ON users(tenant_id, auth_provider) WHERE is_deleted = FALSE;

-- ============================================================================
-- ROLE-BASED ACCESS CONTROL
-- ============================================================================

CREATE TABLE roles (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id),
    role_code           VARCHAR(100) NOT NULL,
    role_name           VARCHAR(200) NOT NULL,
    description         TEXT,
    is_system_role      BOOLEAN NOT NULL DEFAULT FALSE,  -- system roles cannot be deleted
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    custom_attributes   JSONB DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID,
    modified_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by         UUID,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE(tenant_id, role_code)
);
-- Super Admin, Tenant Admin, Manager, User
-- Modules registered in the system
CREATE TABLE modules (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_code         VARCHAR(100) NOT NULL UNIQUE,
    module_name         VARCHAR(200) NOT NULL,
    description         TEXT,
    display_order       INTEGER NOT NULL DEFAULT 0,
    icon                VARCHAR(100),
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Sub-modules within modules
CREATE TABLE sub_modules (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_id           UUID NOT NULL REFERENCES modules(id),
    sub_module_code     VARCHAR(100) NOT NULL,
    sub_module_name     VARCHAR(200) NOT NULL,
    description         TEXT,
    display_order       INTEGER NOT NULL DEFAULT 0,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(module_id, sub_module_code)
);

-- Granular permissions
CREATE TABLE permissions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    module_id           UUID NOT NULL REFERENCES modules(id),
    sub_module_id       UUID REFERENCES sub_modules(id),
    permission_code     VARCHAR(100) NOT NULL,       -- e.g., 'view', 'create', 'edit', 'delete', 'approve', 'export'
    permission_name     VARCHAR(200) NOT NULL,
    description         TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(module_id, sub_module_id, permission_code)
);

-- Role-Permission mapping
CREATE TABLE role_permissions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id             UUID NOT NULL REFERENCES roles(id),
    permission_id       UUID NOT NULL REFERENCES permissions(id),
    granted_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    granted_by          UUID,
    UNIQUE(role_id, permission_id)
);

-- User-Role mapping (with optional entity-level scoping)
CREATE TABLE user_roles (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id),
    role_id             UUID NOT NULL REFERENCES roles(id),
    entity_id           UUID REFERENCES entities(id),  -- NULL = all entities in tenant
    effective_from      DATE NOT NULL DEFAULT CURRENT_DATE,
    effective_to        DATE,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    assigned_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    assigned_by         UUID,
    UNIQUE(user_id, role_id, entity_id)
);

CREATE INDEX idx_user_roles_user ON user_roles(user_id) WHERE is_active = TRUE;
CREATE INDEX idx_user_roles_role ON user_roles(role_id) WHERE is_active = TRUE;

-- User-Entity access mapping (which entities a user can access)
CREATE TABLE user_entity_access (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id),
    entity_id           UUID NOT NULL REFERENCES entities(id),
    access_level        VARCHAR(50) NOT NULL DEFAULT 'full', -- 'full', 'read_only', 'restricted'
    granted_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    granted_by          UUID,
    UNIQUE(user_id, entity_id)
);

-- ============================================================================
-- SESSION MANAGEMENT & SECURITY
-- ============================================================================

CREATE TABLE user_sessions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id),
    tenant_id           UUID NOT NULL REFERENCES tenants(id),
    session_token_hash  VARCHAR(512) NOT NULL,       -- hashed session token
    ip_address          INET,
    user_agent          TEXT,
    login_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_activity_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at          TIMESTAMPTZ NOT NULL,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    revoked_at          TIMESTAMPTZ,
    revoked_reason      VARCHAR(200)
);

CREATE INDEX idx_sessions_user ON user_sessions(user_id, is_active);
CREATE INDEX idx_sessions_expiry ON user_sessions(expires_at) WHERE is_active = TRUE;

-- ============================================================================
-- PASSWORD POLICY (per tenant)
-- ============================================================================

CREATE TABLE password_policies (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL UNIQUE REFERENCES tenants(id),
    min_length          INTEGER NOT NULL DEFAULT 12,
    require_uppercase   BOOLEAN NOT NULL DEFAULT TRUE,
    require_lowercase   BOOLEAN NOT NULL DEFAULT TRUE,
    require_digit       BOOLEAN NOT NULL DEFAULT TRUE,
    require_special     BOOLEAN NOT NULL DEFAULT TRUE,
    max_age_days        INTEGER NOT NULL DEFAULT 90,
    history_count       INTEGER NOT NULL DEFAULT 5,   -- cannot reuse last N passwords
    max_failed_attempts INTEGER NOT NULL DEFAULT 5,
    lockout_duration_min INTEGER NOT NULL DEFAULT 30,
    session_timeout_min INTEGER NOT NULL DEFAULT 30,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by         UUID
);

-- ============================================================================
-- CONFIGURABLE MASTERS (Scoring Scales, Categories, etc.)
-- ============================================================================

CREATE TABLE master_configurations (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id),
    config_type         VARCHAR(100) NOT NULL,       -- 'risk_category', 'likelihood_scale', 'impact_scale', 'control_type', 'issue_rating', etc.
    config_code         VARCHAR(100) NOT NULL,
    config_value        VARCHAR(500) NOT NULL,
    numeric_value       NUMERIC(10,2),               -- for scoring scales
    description         TEXT,
    display_order       INTEGER NOT NULL DEFAULT 0,
    color_code          VARCHAR(20),                 -- for heatmap display
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    custom_attributes   JSONB DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID,
    modified_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by         UUID,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE(tenant_id, config_type, config_code)
);

CREATE INDEX idx_master_config_tenant_type ON master_configurations(tenant_id, config_type) WHERE is_deleted = FALSE;

-- ============================================================================
-- UNIVERSAL AUDIT TRAIL
-- ============================================================================

CREATE TABLE audit_logs (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id),
    user_id             UUID REFERENCES users(id),
    entity_id           UUID REFERENCES entities(id),
    action              audit_action NOT NULL,
    module_code         VARCHAR(100),
    sub_module_code     VARCHAR(100),
    object_type         VARCHAR(100) NOT NULL,       -- e.g., 'risk', 'control', 'finding'
    object_id           UUID NOT NULL,
    object_title        VARCHAR(500),
    changes             JSONB,                       -- {field: {old: ..., new: ...}}
    metadata            JSONB DEFAULT '{}',          -- additional context
    ip_address          INET,
    user_agent          TEXT,
    performed_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Partition audit_logs by month for performance
-- CREATE TABLE audit_logs_2025_01 PARTITION OF audit_logs FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE INDEX idx_audit_logs_tenant_time ON audit_logs(tenant_id, performed_at DESC);
CREATE INDEX idx_audit_logs_object ON audit_logs(tenant_id, object_type, object_id);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id, performed_at DESC);
CREATE INDEX idx_audit_logs_action ON audit_logs(tenant_id, action, performed_at DESC);

-- ============================================================================
-- NOTIFICATION & SMTP SETTINGS
-- ============================================================================

CREATE TABLE notification_settings (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL UNIQUE REFERENCES tenants(id),
    smtp_host           VARCHAR(255),
    smtp_port           INTEGER DEFAULT 587,
    smtp_username       VARCHAR(255),
    smtp_password_enc   VARCHAR(512),                -- encrypted
    smtp_use_tls       BOOLEAN NOT NULL DEFAULT TRUE,
    from_email          VARCHAR(255),
    from_name           VARCHAR(200),
    is_configured       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by         UUID
);

-- ============================================================================
-- DATA IMPORT / UPLOAD MANAGEMENT
-- ============================================================================

CREATE TABLE upload_templates (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id),
    template_name       VARCHAR(200) NOT NULL,
    template_type       VARCHAR(100) NOT NULL,       -- 'trial_balance', 'transactions', 'obligations', 'risks', 'controls'
    file_format         VARCHAR(20) NOT NULL DEFAULT 'xlsx', -- 'xlsx', 'csv'
    column_mapping      JSONB NOT NULL,              -- expected columns and their mappings
    validation_rules    JSONB DEFAULT '{}',          -- validation rules per column
    sample_file_url     VARCHAR(500),
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID,
    modified_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by         UUID,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE(tenant_id, template_name)
);

CREATE TABLE data_imports (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id),
    entity_id           UUID REFERENCES entities(id),
    template_id         UUID REFERENCES upload_templates(id),
    file_name           VARCHAR(500) NOT NULL,
    file_size_bytes     BIGINT,
    file_hash           VARCHAR(128),                -- SHA-256 for integrity check
    storage_path        VARCHAR(1000),               -- secure storage location
    import_type         VARCHAR(100) NOT NULL,
    period_id           UUID REFERENCES financial_periods(id),
    status              VARCHAR(50) NOT NULL DEFAULT 'uploaded', -- 'uploaded', 'validating', 'validated', 'processing', 'completed', 'failed', 'partially_failed'
    total_records       INTEGER DEFAULT 0,
    success_records     INTEGER DEFAULT 0,
    error_records       INTEGER DEFAULT 0,
    error_log           JSONB DEFAULT '[]',          -- array of {row, field, error}
    processing_started  TIMESTAMPTZ,
    processing_completed TIMESTAMPTZ,
    custom_attributes   JSONB DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID,
    modified_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by         UUID,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_data_imports_tenant ON data_imports(tenant_id, import_type) WHERE is_deleted = FALSE;
CREATE INDEX idx_data_imports_status ON data_imports(tenant_id, status) WHERE is_deleted = FALSE;

-- ============================================================================
-- MAPPING RULES ENGINE
-- ============================================================================

CREATE TABLE mapping_rules (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id),
    entity_id           UUID REFERENCES entities(id),
    rule_name           VARCHAR(200) NOT NULL,
    rule_type           VARCHAR(100) NOT NULL,       -- 'tb_account_mapping', 'transaction_category', 'compliance_mapping'
    source_field        VARCHAR(200) NOT NULL,
    source_value        VARCHAR(500),
    source_pattern      VARCHAR(500),                -- regex pattern for flexible matching
    target_field        VARCHAR(200) NOT NULL,
    target_value        VARCHAR(500) NOT NULL,
    priority            INTEGER NOT NULL DEFAULT 0,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    custom_attributes   JSONB DEFAULT '{}',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID,
    modified_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by         UUID,
    is_deleted          BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_mapping_rules_tenant_type ON mapping_rules(tenant_id, rule_type) WHERE is_deleted = FALSE;
