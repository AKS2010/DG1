-- ============================================================================
-- eNFeNITE GRC Intelligence Platform - PostgreSQL Schema
-- Module: Cross-Module Relationships & Views
-- ============================================================================

-- ============================================================================
-- RELATIONSHIP SUMMARY (FK References already defined in individual tables)
-- ============================================================================

/*
┌─────────────────────────────────────────────────────────────────────────┐
│                    ENTITY RELATIONSHIP MAP                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  TENANTS ─────────────────────────────────────────────────────────┐     │
│    │                                                               │     │
│    ├── ENTITIES (1:N)                                             │     │
│    │     ├── FINANCIAL_PERIODS (1:N)                              │     │
│    │     ├── RISKS (1:N) ──── RISK_ASSESSMENTS (1:N)             │     │
│    │     │    ├── RISK_CONTROL_MAPPINGS (M:N) ── CONTROLS (1:N)  │     │
│    │     │    ├── TREATMENT_PLANS (1:N)                           │     │
│    │     │    └── INCIDENTS (N:1 back-ref)                        │     │
│    │     │                                                        │     │
│    │     ├── CONTROLS (1:N) ── CONTROL_TESTS (1:N)               │     │
│    │     │                                                        │     │
│    │     ├── ASSESSMENT_PLANS (1:N)                               │     │
│    │     │    ├── QUESTIONNAIRES (1:N)                            │     │
│    │     │    │    └── QUESTIONS (1:N) ── ASSESSMENT_RESPONSES    │     │
│    │     │    ├── FINDINGS (1:N)                                  │     │
│    │     │    └── PBC_QUERIES (1:N)                               │     │
│    │     │                                                        │     │
│    │     ├── COMPLIANCE_OBLIGATIONS (1:N)                         │     │
│    │     │    └── COMPLIANCE_CALENDAR_ITEMS (1:N)                 │     │
│    │     │                                                        │     │
│    │     ├── ACCOUNTS (1:N) ── TRIAL_BALANCE_ENTRIES (1:N)       │     │
│    │     │                  ── FINANCIAL_TRANSACTIONS (1:N)       │     │
│    │     │                                                        │     │
│    │     ├── ACTIONS (1:N) -- linked to any source object         │     │
│    │     └── INCIDENTS (1:N)                                      │     │
│    │                                                              │     │
│    ├── USERS (1:N)                                                │     │
│    │     ├── USER_ROLES (M:N) ── ROLES (1:N)                    │     │
│    │     │                        └── ROLE_PERMISSIONS (M:N)     │     │
│    │     │                             └── PERMISSIONS           │     │
│    │     └── USER_ENTITY_ACCESS (M:N)                            │     │
│    │                                                              │     │
│    ├── FRAMEWORKS (1:N)                                           │     │
│    │     ├── FRAMEWORK_DOMAINS (1:N, hierarchical)               │     │
│    │     └── FRAMEWORK_REQUIREMENTS (1:N)                        │     │
│    │                                                              │     │
│    ├── DOCUMENTS (1:N) ── DOCUMENT_VERSIONS (1:N)                │     │
│    │                                                              │     │
│    ├── EVIDENCE_RECORDS (1:N) ── EVIDENCE_LINKS (polymorphic)    │     │
│    │                                                              │     │
│    ├── ALERTS (1:N) ── ALERT_USER_STATUS (1:N)                   │     │
│    │                                                              │     │
│    ├── COA_GROUPS (1:N, hierarchical)                            │     │
│    │                                                              │     │
│    ├── TRAINING_COURSES (1:N) ── TRAINING_ASSIGNMENTS (1:N)      │     │
│    │                                                              │     │
│    ├── CUSTOM_FIELD_DEFINITIONS (1:N) ── CUSTOM_FIELD_VALUES     │     │
│    │                                                              │     │
│    └── AUDIT_LOGS (1:N, append-only)                             │     │
│                                                                   │     │
└───────────────────────────────────────────────────────────────────┘     │
                                                                           │
  CROSS-MODULE LINKS:                                                      │
  • Findings → Risks, Controls, Framework Requirements                     │
  • Actions → Any source object (polymorphic via source_object_type/id)    │
  • Evidence → Any GRC object (polymorphic via evidence_links)             │
  • Documents → Any GRC object (polymorphic via document_links)            │
  • Alerts → Any source object (polymorphic)                               │
  • Compliance Obligations → Frameworks, Framework Requirements            │
  • Incidents → Risks, Controls                                            │
  • Training → Compliance Obligations, Frameworks                          │
  • Risk-Control → M:N through risk_control_mappings                       │
  • Assessment Plans → Frameworks                                          │
  • Questions → Framework Requirements                                     │
                                                                           │
└─────────────────────────────────────────────────────────────────────────┘
*/

-- ============================================================================
-- USEFUL VIEWS FOR DASHBOARDS AND REPORTING
-- ============================================================================

-- Risk Summary View (Dashboard widget)
CREATE OR REPLACE VIEW vw_risk_summary AS
SELECT 
    r.tenant_id,
    r.entity_id,
    e.entity_name,
    r.risk_type,
    r.risk_category,
    COUNT(*) AS total_risks,
    COUNT(*) FILTER (WHERE r.inherent_score >= 20) AS critical_risks,
    COUNT(*) FILTER (WHERE r.inherent_score >= 12 AND r.inherent_score < 20) AS high_risks,
    COUNT(*) FILTER (WHERE r.inherent_score >= 6 AND r.inherent_score < 12) AS medium_risks,
    COUNT(*) FILTER (WHERE r.inherent_score < 6) AS low_risks,
    AVG(r.inherent_score) AS avg_inherent_score,
    AVG(r.residual_score) AS avg_residual_score,
    COUNT(*) FILTER (WHERE r.status = 'active') AS active_risks,
    COUNT(*) FILTER (WHERE r.next_review_date < CURRENT_DATE) AS overdue_reviews
FROM risks r
JOIN entities e ON e.id = r.entity_id
WHERE r.is_deleted = FALSE
GROUP BY r.tenant_id, r.entity_id, e.entity_name, r.risk_type, r.risk_category;

-- Open Actions Summary (Dashboard widget)
CREATE OR REPLACE VIEW vw_actions_summary AS
SELECT
    a.tenant_id,
    a.entity_id,
    a.source_module,
    a.priority,
    a.status,
    COUNT(*) AS action_count,
    COUNT(*) FILTER (WHERE a.due_date < CURRENT_DATE AND a.status NOT IN ('completed', 'cancelled')) AS overdue_count,
    COUNT(*) FILTER (WHERE a.due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days') AS due_this_week,
    AVG(EXTRACT(DAY FROM (COALESCE(a.completion_date, CURRENT_DATE)::TIMESTAMP - a.created_at))) AS avg_aging_days
FROM actions a
WHERE a.is_deleted = FALSE
GROUP BY a.tenant_id, a.entity_id, a.source_module, a.priority, a.status;

-- Compliance Status Overview
CREATE OR REPLACE VIEW vw_compliance_status AS
SELECT
    cci.tenant_id,
    cci.entity_id,
    co.obligation_type,
    co.category,
    cci.compliance_status,
    COUNT(*) AS item_count,
    COUNT(*) FILTER (WHERE cci.due_date < CURRENT_DATE AND cci.compliance_status = 'pending_review') AS overdue_count,
    COUNT(*) FILTER (WHERE cci.due_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '30 days' AND cci.compliance_status = 'pending_review') AS due_next_30_days
FROM compliance_calendar_items cci
JOIN compliance_obligations co ON co.id = cci.obligation_id
WHERE cci.is_deleted = FALSE AND co.is_deleted = FALSE
GROUP BY cci.tenant_id, cci.entity_id, co.obligation_type, co.category, cci.compliance_status;

-- Assessment Progress View
CREATE OR REPLACE VIEW vw_assessment_progress AS
SELECT
    ap.tenant_id,
    ap.entity_id,
    ap.plan_code,
    ap.plan_title,
    ap.plan_type,
    ap.status,
    ap.overall_rating,
    ap.planned_start_date,
    ap.planned_end_date,
    COUNT(DISTINCT f.id) AS total_findings,
    COUNT(DISTINCT f.id) FILTER (WHERE f.severity IN ('critical', 'high')) AS high_findings,
    COUNT(DISTINCT pq.id) AS total_queries,
    COUNT(DISTINCT pq.id) FILTER (WHERE pq.status = 'open') AS open_queries
FROM assessment_plans ap
LEFT JOIN findings f ON f.assessment_plan_id = ap.id AND f.is_deleted = FALSE
LEFT JOIN pbc_queries pq ON pq.assessment_plan_id = ap.id AND pq.is_deleted = FALSE
WHERE ap.is_deleted = FALSE
GROUP BY ap.tenant_id, ap.entity_id, ap.plan_code, ap.plan_title, ap.plan_type, ap.status, ap.overall_rating, ap.planned_start_date, ap.planned_end_date;

-- Finance KPI Dashboard View
CREATE OR REPLACE VIEW vw_finance_kpi_latest AS
SELECT
    k.tenant_id,
    k.entity_id,
    k.kpi_code,
    k.kpi_name,
    k.kpi_category,
    k.current_value,
    k.previous_month_value,
    k.ytd_value,
    k.mom_variance_pct,
    k.yoy_variance_pct,
    k.is_breach,
    k.period_month,
    k.period_year
FROM kpi_results k
INNER JOIN (
    SELECT tenant_id, entity_id, kpi_code, MAX(period_year * 100 + period_month) AS max_period
    FROM kpi_results WHERE is_deleted = FALSE
    GROUP BY tenant_id, entity_id, kpi_code
) latest ON k.tenant_id = latest.tenant_id 
    AND k.entity_id = latest.entity_id 
    AND k.kpi_code = latest.kpi_code
    AND (k.period_year * 100 + k.period_month) = latest.max_period
WHERE k.is_deleted = FALSE;

-- Control Effectiveness Summary
CREATE OR REPLACE VIEW vw_control_effectiveness AS
SELECT
    c.tenant_id,
    c.entity_id,
    c.control_type,
    c.control_nature,
    c.design_effectiveness,
    c.operating_effectiveness,
    COUNT(*) AS control_count,
    COUNT(*) FILTER (WHERE c.next_test_due < CURRENT_DATE) AS overdue_testing,
    COUNT(*) FILTER (WHERE c.design_effectiveness = 'ineffective' OR c.operating_effectiveness = 'ineffective') AS ineffective_controls
FROM controls c
WHERE c.is_deleted = FALSE AND c.status = 'active'
GROUP BY c.tenant_id, c.entity_id, c.control_type, c.control_nature, c.design_effectiveness, c.operating_effectiveness;

-- ============================================================================
-- MATERIALIZED VIEW FOR DASHBOARD GRC SCORE
-- ============================================================================

CREATE MATERIALIZED VIEW mv_grc_score AS
SELECT
    t.id AS tenant_id,
    e.id AS entity_id,
    e.entity_name,
    
    -- Risk Score (lower is better: avg residual / max possible * 100)
    COALESCE(ROUND(AVG(r.residual_score) / 25.0 * 100, 1), 0) AS risk_exposure_pct,
    
    -- Control Effectiveness (% effective)
    COALESCE(
        ROUND(
            COUNT(c.id) FILTER (WHERE c.design_effectiveness = 'effective' AND c.operating_effectiveness = 'effective')::NUMERIC
            / NULLIF(COUNT(c.id), 0) * 100, 1
        ), 0
    ) AS control_effectiveness_pct,
    
    -- Compliance Rate (% compliant items)
    COALESCE(
        ROUND(
            COUNT(cci.id) FILTER (WHERE cci.compliance_status = 'compliant')::NUMERIC
            / NULLIF(COUNT(cci.id), 0) * 100, 1
        ), 0
    ) AS compliance_rate_pct,
    
    -- Action Closure Rate
    COALESCE(
        ROUND(
            COUNT(a.id) FILTER (WHERE a.status = 'completed')::NUMERIC
            / NULLIF(COUNT(a.id), 0) * 100, 1
        ), 0
    ) AS action_closure_rate_pct,
    
    NOW() AS computed_at
    
FROM tenants t
JOIN entities e ON e.tenant_id = t.id AND e.is_deleted = FALSE
LEFT JOIN risks r ON r.entity_id = e.id AND r.is_deleted = FALSE AND r.status = 'active'
LEFT JOIN controls c ON c.entity_id = e.id AND c.is_deleted = FALSE AND c.status = 'active'
LEFT JOIN compliance_calendar_items cci ON cci.entity_id = e.id AND cci.is_deleted = FALSE
LEFT JOIN actions a ON a.entity_id = e.id AND a.is_deleted = FALSE
WHERE t.is_deleted = FALSE
GROUP BY t.id, e.id, e.entity_name;

-- Refresh daily or on-demand
-- CREATE UNIQUE INDEX idx_mv_grc_score ON mv_grc_score(tenant_id, entity_id);

-- ============================================================================
-- HELPER FUNCTION: Generate sequential codes
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_code(
    p_tenant_id UUID,
    p_entity_id UUID,
    p_prefix VARCHAR(10),
    p_table_name VARCHAR(100)
)
RETURNS VARCHAR(50) AS $$
DECLARE
    v_next_seq INTEGER;
    v_code VARCHAR(50);
BEGIN
    -- Get next sequence number for this tenant/entity/prefix combination
    EXECUTE format(
        'SELECT COALESCE(MAX(CAST(SUBSTRING(%I FROM ''[0-9]+$'') AS INTEGER)), 0) + 1 
         FROM %I WHERE tenant_id = $1 AND entity_id = $2',
        p_prefix || '_code', p_table_name
    ) INTO v_next_seq USING p_tenant_id, p_entity_id;
    
    v_code := p_prefix || '-' || LPAD(v_next_seq::TEXT, 4, '0');
    RETURN v_code;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- NOTIFICATION QUEUE (for async notification processing)
-- ============================================================================

CREATE TABLE notification_queue (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    
    notification_type       VARCHAR(50) NOT NULL,     -- 'email', 'in_app', 'sms'
    recipient_user_id       UUID NOT NULL REFERENCES users(id),
    recipient_email         VARCHAR(255),
    
    subject                 VARCHAR(500),
    body_text               TEXT,
    body_html               TEXT,
    
    -- Reference
    related_object_type     VARCHAR(100),
    related_object_id       UUID,
    
    -- Processing
    status                  VARCHAR(50) NOT NULL DEFAULT 'pending', -- 'pending', 'processing', 'sent', 'failed', 'cancelled'
    attempts                INTEGER DEFAULT 0,
    max_attempts            INTEGER DEFAULT 3,
    last_attempt_at         TIMESTAMPTZ,
    error_message           TEXT,
    sent_at                 TIMESTAMPTZ,
    
    -- Scheduling
    scheduled_for           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notification_queue_pending ON notification_queue(scheduled_for) WHERE status = 'pending';
CREATE INDEX idx_notification_queue_user ON notification_queue(recipient_user_id, created_at DESC);
