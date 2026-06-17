-- ============================================================================
-- eNFeNITE GRC Intelligence Platform - PostgreSQL Schema
-- Module: Row-Level Security (RLS), Security Policies, and Cross-Module Relationships
-- ============================================================================

-- ============================================================================
-- ROW-LEVEL SECURITY (Multi-Tenant Data Isolation)
-- ============================================================================

-- Enable RLS on all tenant-scoped tables
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE entities ENABLE ROW LEVEL SECURITY;
ALTER TABLE financial_periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_entity_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE master_configurations ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE risks ENABLE ROW LEVEL SECURITY;
ALTER TABLE risk_assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE controls ENABLE ROW LEVEL SECURITY;
ALTER TABLE risk_control_mappings ENABLE ROW LEVEL SECURITY;
ALTER TABLE control_tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE treatment_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE frameworks ENABLE ROW LEVEL SECURITY;
ALTER TABLE assessment_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE questionnaires ENABLE ROW LEVEL SECURITY;
ALTER TABLE assessment_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE findings ENABLE ROW LEVEL SECURITY;
ALTER TABLE pbc_queries ENABLE ROW LEVEL SECURITY;
ALTER TABLE compliance_obligations ENABLE ROW LEVEL SECURITY;
ALTER TABLE compliance_calendar_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE regulatory_updates ENABLE ROW LEVEL SECURITY;
ALTER TABLE coa_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE trial_balance_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE financial_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE cashflow_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE kpi_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE finance_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE evidence_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE evidence_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_imports ENABLE ROW LEVEL SECURITY;
ALTER TABLE custom_field_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE custom_field_values ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- RLS POLICIES
-- Application sets current_setting('app.current_tenant_id') on each connection
-- ============================================================================

-- Template policy: tenants can only see their own data
-- Applied to every tenant-scoped table

CREATE POLICY tenant_isolation_tenants ON tenants
    USING (id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_entities ON entities
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_users ON users
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_roles ON roles
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_risks ON risks
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_controls ON controls
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_findings ON findings
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_actions ON actions
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_compliance ON compliance_obligations
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_documents ON documents
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_evidence ON evidence_records
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_assessments ON assessment_plans
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_alerts ON alerts
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_audit_logs ON audit_logs
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_fin_txn ON financial_transactions
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_tb ON trial_balance_entries
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_kpi ON kpi_results
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_training ON training_courses
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_training_assignments ON training_assignments
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_custom_fields ON custom_field_definitions
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_custom_values ON custom_field_values
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_data_imports ON data_imports
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_incidents ON incidents
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_frameworks ON frameworks
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_questionnaires ON questionnaires
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_responses ON assessment_responses
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_pbc ON pbc_queries
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_calendar ON compliance_calendar_items
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_reg_updates ON regulatory_updates
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_coa ON coa_groups
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_accounts ON accounts
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_cashflow ON cashflow_entries
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

CREATE POLICY tenant_isolation_finance_alerts ON finance_alerts
    USING (tenant_id = current_setting('app.current_tenant_id')::UUID);

-- ============================================================================
-- CONFIDENTIAL DOCUMENT ACCESS (Additional RLS for restricted documents)
-- ============================================================================

-- Documents with 'restricted' confidentiality only visible to owner/custodian or users with explicit access
CREATE POLICY restricted_documents ON documents
    USING (
        confidentiality_level != 'restricted'
        OR document_owner_id = current_setting('app.current_user_id')::UUID
        OR custodian_id = current_setting('app.current_user_id')::UUID
    );

-- Evidence with restricted_access only visible to linked object owners
CREATE POLICY restricted_evidence ON evidence_records
    USING (
        restricted_access = FALSE
        OR created_by = current_setting('app.current_user_id')::UUID
    );

-- ============================================================================
-- DATA ENCRYPTION FUNCTIONS
-- ============================================================================

-- Function to encrypt sensitive data at rest
CREATE OR REPLACE FUNCTION encrypt_sensitive(plain_text TEXT, encryption_key TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN encode(pgp_sym_encrypt(plain_text, encryption_key), 'base64');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to decrypt sensitive data
CREATE OR REPLACE FUNCTION decrypt_sensitive(encrypted_text TEXT, encryption_key TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN pgp_sym_decrypt(decode(encrypted_text, 'base64'), encryption_key);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- TRIGGER: Auto-update modified_at timestamp
-- ============================================================================

CREATE OR REPLACE FUNCTION update_modified_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.modified_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all major tables
CREATE TRIGGER trg_tenants_modified BEFORE UPDATE ON tenants FOR EACH ROW EXECUTE FUNCTION update_modified_at();
CREATE TRIGGER trg_entities_modified BEFORE UPDATE ON entities FOR EACH ROW EXECUTE FUNCTION update_modified_at();
CREATE TRIGGER trg_users_modified BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_modified_at();
CREATE TRIGGER trg_risks_modified BEFORE UPDATE ON risks FOR EACH ROW EXECUTE FUNCTION update_modified_at();
CREATE TRIGGER trg_controls_modified BEFORE UPDATE ON controls FOR EACH ROW EXECUTE FUNCTION update_modified_at();
CREATE TRIGGER trg_findings_modified BEFORE UPDATE ON findings FOR EACH ROW EXECUTE FUNCTION update_modified_at();
CREATE TRIGGER trg_actions_modified BEFORE UPDATE ON actions FOR EACH ROW EXECUTE FUNCTION update_modified_at();
CREATE TRIGGER trg_compliance_modified BEFORE UPDATE ON compliance_obligations FOR EACH ROW EXECUTE FUNCTION update_modified_at();
CREATE TRIGGER trg_documents_modified BEFORE UPDATE ON documents FOR EACH ROW EXECUTE FUNCTION update_modified_at();
CREATE TRIGGER trg_assessment_plans_modified BEFORE UPDATE ON assessment_plans FOR EACH ROW EXECUTE FUNCTION update_modified_at();
CREATE TRIGGER trg_incidents_modified BEFORE UPDATE ON incidents FOR EACH ROW EXECUTE FUNCTION update_modified_at();
CREATE TRIGGER trg_treatment_plans_modified BEFORE UPDATE ON treatment_plans FOR EACH ROW EXECUTE FUNCTION update_modified_at();
CREATE TRIGGER trg_training_courses_modified BEFORE UPDATE ON training_courses FOR EACH ROW EXECUTE FUNCTION update_modified_at();

-- ============================================================================
-- TRIGGER: Soft-delete cascade (set deleted_at timestamp)
-- ============================================================================

CREATE OR REPLACE FUNCTION set_deleted_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_deleted = TRUE AND OLD.is_deleted = FALSE THEN
        NEW.deleted_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_risks_soft_delete BEFORE UPDATE ON risks FOR EACH ROW EXECUTE FUNCTION set_deleted_timestamp();
CREATE TRIGGER trg_controls_soft_delete BEFORE UPDATE ON controls FOR EACH ROW EXECUTE FUNCTION set_deleted_timestamp();
CREATE TRIGGER trg_findings_soft_delete BEFORE UPDATE ON findings FOR EACH ROW EXECUTE FUNCTION set_deleted_timestamp();
CREATE TRIGGER trg_documents_soft_delete BEFORE UPDATE ON documents FOR EACH ROW EXECUTE FUNCTION set_deleted_timestamp();
CREATE TRIGGER trg_users_soft_delete BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION set_deleted_timestamp();
CREATE TRIGGER trg_incidents_soft_delete BEFORE UPDATE ON incidents FOR EACH ROW EXECUTE FUNCTION set_deleted_timestamp();

-- ============================================================================
-- TRIGGER: Version increment on update
-- ============================================================================

CREATE OR REPLACE FUNCTION increment_version()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_deleted = OLD.is_deleted THEN  -- don't increment on soft delete
        NEW.version = OLD.version + 1;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_risks_version BEFORE UPDATE ON risks FOR EACH ROW EXECUTE FUNCTION increment_version();
CREATE TRIGGER trg_controls_version BEFORE UPDATE ON controls FOR EACH ROW EXECUTE FUNCTION increment_version();

-- ============================================================================
-- TRIGGER: Auto-populate search_vector for documents
-- ============================================================================

CREATE OR REPLACE FUNCTION update_document_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector = 
        setweight(to_tsvector('english', COALESCE(NEW.document_title, '')), 'A') ||
        setweight(to_tsvector('english', COALESCE(NEW.category, '')), 'B') ||
        setweight(to_tsvector('english', COALESCE(NEW.rich_text_content, '')), 'C') ||
        setweight(to_tsvector('english', COALESCE(array_to_string(NEW.tags, ' '), '')), 'B');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_documents_search_vector 
    BEFORE INSERT OR UPDATE ON documents 
    FOR EACH ROW EXECUTE FUNCTION update_document_search_vector();

-- ============================================================================
-- DATABASE ROLES FOR APPLICATION LAYERS
-- ============================================================================

-- Application service role (used by the backend)
-- CREATE ROLE app_service LOGIN PASSWORD '<secure-password>';
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO app_service;
-- GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_service;

-- Read-only reporting role
-- CREATE ROLE app_readonly LOGIN PASSWORD '<secure-password>';
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_readonly;

-- Admin role (for migrations and DDL)
-- CREATE ROLE app_admin LOGIN PASSWORD '<secure-password>';
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_admin;

-- ============================================================================
-- ADDITIONAL SECURITY MEASURES
-- ============================================================================

-- Prevent direct DELETE on critical tables (force soft-delete)
CREATE OR REPLACE FUNCTION prevent_hard_delete()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Hard deletes are not allowed on this table. Use soft-delete (SET is_deleted = TRUE) instead.';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_delete_risks BEFORE DELETE ON risks FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER trg_prevent_delete_controls BEFORE DELETE ON controls FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER trg_prevent_delete_findings BEFORE DELETE ON findings FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER trg_prevent_delete_documents BEFORE DELETE ON documents FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER trg_prevent_delete_audit_logs BEFORE DELETE ON audit_logs FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER trg_prevent_delete_compliance BEFORE DELETE ON compliance_obligations FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER trg_prevent_delete_users BEFORE DELETE ON users FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE TRIGGER trg_prevent_delete_evidence BEFORE DELETE ON evidence_records FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
