-- ============================================================================
-- eNFeNITE GRC Intelligence Platform - PostgreSQL Schema
-- Module: Finance Intelligence
-- Sub-modules: Trial Balance, Transactions, Chart of Accounts Mapping,
--              KPI Computation, Alerts & Anomalies
-- ============================================================================

-- ============================================================================
-- CHART OF ACCOUNTS GROUPS (Standardized mapping categories)
-- ============================================================================

CREATE TABLE coa_groups (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    
    group_code              VARCHAR(50) NOT NULL,
    group_name              VARCHAR(300) NOT NULL,
    parent_group_id         UUID REFERENCES coa_groups(id),
    group_type              VARCHAR(50) NOT NULL,     -- 'asset', 'liability', 'equity', 'revenue', 'expense', 'cogs'
    level                   INTEGER NOT NULL DEFAULT 1,
    display_order           INTEGER NOT NULL DEFAULT 0,
    
    -- KPI mapping
    kpi_category            VARCHAR(100),             -- maps to KPI computation: 'revenue', 'gross_margin', 'operating_expense', 'receivable', 'payable', 'cash'
    
    is_system_group         BOOLEAN NOT NULL DEFAULT FALSE,
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID,
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID,
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE(tenant_id, group_code)
);

CREATE INDEX idx_coa_groups_tenant ON coa_groups(tenant_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_coa_groups_parent ON coa_groups(parent_group_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_coa_groups_type ON coa_groups(tenant_id, group_type) WHERE is_deleted = FALSE;

-- ============================================================================
-- ACCOUNT MASTER (Mapped from uploaded TB)
-- ============================================================================

CREATE TABLE accounts (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    entity_id               UUID NOT NULL REFERENCES entities(id),
    
    account_code            VARCHAR(100) NOT NULL,
    account_name            VARCHAR(500) NOT NULL,
    coa_group_id            UUID REFERENCES coa_groups(id),
    
    account_type            VARCHAR(50),             -- 'asset', 'liability', 'equity', 'revenue', 'expense'
    sub_type                VARCHAR(100),            -- more granular classification
    
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID,
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID,
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE(tenant_id, entity_id, account_code)
);

CREATE INDEX idx_accounts_tenant_entity ON accounts(tenant_id, entity_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_accounts_coa_group ON accounts(coa_group_id) WHERE is_deleted = FALSE;

-- ============================================================================
-- TRIAL BALANCE UPLOADS (Period-wise TB data)
-- ============================================================================

CREATE TABLE trial_balance_entries (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    entity_id               UUID NOT NULL REFERENCES entities(id),
    import_id               UUID NOT NULL REFERENCES data_imports(id),
    period_id               UUID NOT NULL REFERENCES financial_periods(id),
    account_id              UUID REFERENCES accounts(id),
    
    -- Period info
    period_month            INTEGER NOT NULL CHECK (period_month BETWEEN 1 AND 12),
    period_year             INTEGER NOT NULL,
    
    -- Original uploaded data
    account_code_raw        VARCHAR(100) NOT NULL,
    account_name_raw        VARCHAR(500),
    
    -- Balances
    opening_balance         NUMERIC(18,2) DEFAULT 0,
    debit_amount            NUMERIC(18,2) DEFAULT 0,
    credit_amount           NUMERIC(18,2) DEFAULT 0,
    closing_balance         NUMERIC(18,2) DEFAULT 0,
    
    currency                VARCHAR(10) DEFAULT 'INR',
    
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID,
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_tb_entries_tenant_entity ON trial_balance_entries(tenant_id, entity_id, period_year, period_month) WHERE is_deleted = FALSE;
CREATE INDEX idx_tb_entries_account ON trial_balance_entries(account_id, period_year, period_month) WHERE is_deleted = FALSE;
CREATE INDEX idx_tb_entries_import ON trial_balance_entries(import_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_tb_entries_period ON trial_balance_entries(period_id) WHERE is_deleted = FALSE;

-- ============================================================================
-- TRANSACTION DATA (GL / Ledger Extracts / Sales & Purchase Register)
-- ============================================================================

CREATE TABLE financial_transactions (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    entity_id               UUID NOT NULL REFERENCES entities(id),
    import_id               UUID NOT NULL REFERENCES data_imports(id),
    period_id               UUID REFERENCES financial_periods(id),
    account_id              UUID REFERENCES accounts(id),
    
    -- Transaction details
    transaction_date        DATE NOT NULL,
    voucher_type            VARCHAR(100),             -- 'journal', 'receipt', 'payment', 'sales', 'purchase', 'contra'
    voucher_number          VARCHAR(200),
    
    -- Party info
    party_name              VARCHAR(500),
    party_code              VARCHAR(100),
    
    -- Amounts
    debit_amount            NUMERIC(18,2) DEFAULT 0,
    credit_amount           NUMERIC(18,2) DEFAULT 0,
    net_amount              NUMERIC(18,2) GENERATED ALWAYS AS (debit_amount - credit_amount) STORED,
    currency                VARCHAR(10) DEFAULT 'INR',
    
    -- Categorization
    narration               TEXT,
    cost_center             VARCHAR(200),
    project_code            VARCHAR(100),
    
    -- Original raw data
    account_code_raw        VARCHAR(100),
    account_name_raw        VARCHAR(500),
    
    -- Analytics flags (populated by processing engine)
    is_flagged              BOOLEAN DEFAULT FALSE,
    flag_reason             VARCHAR(500),             -- 'duplicate_payment', 'unusual_amount', 'weekend_transaction', etc.
    
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_fin_txn_tenant_entity ON financial_transactions(tenant_id, entity_id, transaction_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_fin_txn_account ON financial_transactions(account_id, transaction_date) WHERE is_deleted = FALSE;
CREATE INDEX idx_fin_txn_party ON financial_transactions(tenant_id, party_name) WHERE is_deleted = FALSE;
CREATE INDEX idx_fin_txn_import ON financial_transactions(import_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_fin_txn_flagged ON financial_transactions(tenant_id, is_flagged) WHERE is_flagged = TRUE AND is_deleted = FALSE;
CREATE INDEX idx_fin_txn_voucher ON financial_transactions(tenant_id, voucher_number) WHERE is_deleted = FALSE;

-- ============================================================================
-- BANK & CASH FLOW DATA
-- ============================================================================

CREATE TABLE cashflow_entries (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    entity_id               UUID NOT NULL REFERENCES entities(id),
    import_id               UUID REFERENCES data_imports(id),
    period_id               UUID REFERENCES financial_periods(id),
    
    entry_date              DATE NOT NULL,
    bank_account            VARCHAR(200),
    description             TEXT,
    
    -- Amounts
    inflow_amount           NUMERIC(18,2) DEFAULT 0,
    outflow_amount          NUMERIC(18,2) DEFAULT 0,
    balance                 NUMERIC(18,2),
    currency                VARCHAR(10) DEFAULT 'INR',
    
    -- Classification
    cashflow_category       VARCHAR(100),             -- 'operating', 'investing', 'financing'
    sub_category            VARCHAR(200),
    
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_cashflow_tenant_entity ON cashflow_entries(tenant_id, entity_id, entry_date) WHERE is_deleted = FALSE;

-- ============================================================================
-- KPI RESULTS (Computed from uploaded financial data)
-- ============================================================================

CREATE TABLE kpi_results (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    entity_id               UUID NOT NULL REFERENCES entities(id),
    period_id               UUID REFERENCES financial_periods(id),
    
    -- Period
    period_month            INTEGER NOT NULL CHECK (period_month BETWEEN 1 AND 12),
    period_year             INTEGER NOT NULL,
    
    -- KPI Definition
    kpi_code                VARCHAR(100) NOT NULL,    -- 'revenue', 'gross_margin', 'ebitda_proxy', 'current_ratio', 'dso', 'dpo', 'cash_runway', etc.
    kpi_name                VARCHAR(300) NOT NULL,
    kpi_category            VARCHAR(100),             -- 'profitability', 'liquidity', 'efficiency', 'leverage', 'growth'
    
    -- Values
    current_value           NUMERIC(18,4),
    previous_month_value    NUMERIC(18,4),
    ytd_value               NUMERIC(18,4),
    previous_year_value     NUMERIC(18,4),
    
    -- Variance
    mom_variance            NUMERIC(18,4),            -- month-over-month
    mom_variance_pct        NUMERIC(10,4),
    yoy_variance            NUMERIC(18,4),            -- year-over-year
    yoy_variance_pct        NUMERIC(10,4),
    
    -- Thresholds
    threshold_min           NUMERIC(18,4),
    threshold_max           NUMERIC(18,4),
    is_breach               BOOLEAN DEFAULT FALSE,
    
    -- Metadata
    computation_formula     TEXT,
    data_quality_score      NUMERIC(5,2),             -- confidence in data completeness
    computed_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE(tenant_id, entity_id, period_year, period_month, kpi_code)
);

CREATE INDEX idx_kpi_results_tenant_entity ON kpi_results(tenant_id, entity_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_kpi_results_period ON kpi_results(period_year, period_month) WHERE is_deleted = FALSE;
CREATE INDEX idx_kpi_results_breach ON kpi_results(tenant_id, is_breach) WHERE is_breach = TRUE AND is_deleted = FALSE;

-- ============================================================================
-- FINANCE ALERTS (Anomalies, Exceptions, Flags)
-- ============================================================================

CREATE TABLE finance_alerts (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    entity_id               UUID NOT NULL REFERENCES entities(id),
    
    alert_code              VARCHAR(100) NOT NULL,
    alert_title             VARCHAR(500) NOT NULL,
    alert_category          VARCHAR(100) NOT NULL,    -- 'duplicate_payment', 'unusual_variance', 'negative_margin', 'cash_stress', 'overdue_receivable', 'balance_anomaly'
    description             TEXT,
    
    -- Linked data
    related_transaction_ids UUID[] DEFAULT '{}',
    related_account_ids     UUID[] DEFAULT '{}',
    related_kpi_id          UUID REFERENCES kpi_results(id),
    
    -- Severity & Amount
    severity                finding_severity NOT NULL DEFAULT 'medium',
    flagged_amount          NUMERIC(18,2),
    currency                VARCHAR(10) DEFAULT 'INR',
    
    -- Period
    period_month            INTEGER,
    period_year             INTEGER,
    
    -- Resolution
    assigned_to             UUID REFERENCES users(id),
    status                  action_status NOT NULL DEFAULT 'open',
    resolution_notes        TEXT,
    resolved_by             UUID REFERENCES users(id),
    resolved_at             TIMESTAMPTZ,
    
    -- Auto-generated?
    is_system_generated     BOOLEAN NOT NULL DEFAULT TRUE,
    
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID,
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID,
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX idx_finance_alerts_tenant ON finance_alerts(tenant_id, entity_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_finance_alerts_status ON finance_alerts(tenant_id, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_finance_alerts_severity ON finance_alerts(tenant_id, severity) WHERE is_deleted = FALSE;
CREATE INDEX idx_finance_alerts_category ON finance_alerts(tenant_id, alert_category) WHERE is_deleted = FALSE;
