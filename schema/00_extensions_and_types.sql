-- ============================================================================
-- eNFeNITE GRC Intelligence Platform - PostgreSQL Schema
-- Module: Extensions & Custom Types
-- Description: Required extensions and enumerated types used across the platform
-- ============================================================================

-- Required Extensions
-- Note: UUID generation uses gen_random_uuid() which is built into PostgreSQL 13+
-- core (and also provided by pgcrypto). This avoids the uuid-ossp extension,
-- which is not allow-listed by default on Azure Database for PostgreSQL.
CREATE EXTENSION IF NOT EXISTS "pgcrypto";         -- Encryption / hashing functions (also exposes gen_random_uuid)
CREATE EXTENSION IF NOT EXISTS "pg_trgm";          -- Trigram-based text search
CREATE EXTENSION IF NOT EXISTS "btree_gin";        -- GIN index support for scalars

-- ============================================================================
-- ENUMERATED TYPES
-- ============================================================================

-- Lifecycle statuses used across all core objects
CREATE TYPE lifecycle_status AS ENUM (
    'draft', 'under_review', 'approved', 'active', 'closed', 'archived', 'rejected'
);

-- Risk types
CREATE TYPE risk_type AS ENUM (
    'financial', 'operational', 'compliance', 'it_cyber', 'fraud', 'reporting', 'third_party', 'strategic'
);

-- Control types
CREATE TYPE control_type AS ENUM ('preventive', 'detective', 'corrective');

-- Control nature
CREATE TYPE control_nature AS ENUM ('manual', 'automated', 'it_dependent_manual');

-- Treatment strategies
CREATE TYPE treatment_strategy AS ENUM ('accept', 'mitigate', 'transfer', 'avoid');

-- Priority levels
CREATE TYPE priority_level AS ENUM ('critical', 'high', 'medium', 'low', 'informational');

-- Assessment rating
CREATE TYPE assessment_rating AS ENUM ('effective', 'partially_effective', 'ineffective', 'not_assessed');

-- Finding severity
CREATE TYPE finding_severity AS ENUM ('critical', 'high', 'medium', 'low', 'observation');

-- Action status
CREATE TYPE action_status AS ENUM ('open', 'in_progress', 'overdue', 'completed', 'cancelled', 'escalated');

-- Compliance status
CREATE TYPE compliance_status AS ENUM ('compliant', 'partially_compliant', 'non_compliant', 'not_applicable', 'pending_review');

-- Alert type
CREATE TYPE alert_type AS ENUM ('threshold_breach', 'due_date', 'overdue', 'exception', 'anomaly', 'escalation', 'system');

-- Document type
CREATE TYPE document_type AS ENUM ('policy', 'procedure', 'sop', 'work_instruction', 'guideline', 'form', 'template', 'report', 'evidence', 'other');

-- Frequency
CREATE TYPE frequency_type AS ENUM ('daily', 'weekly', 'fortnightly', 'monthly', 'quarterly', 'semi_annual', 'annual', 'ad_hoc', 'continuous');

-- Audit action types for audit trail
CREATE TYPE audit_action AS ENUM ('create', 'update', 'delete', 'approve', 'reject', 'upload', 'download', 'review', 'close', 'reopen', 'assign', 'escalate', 'login', 'logout', 'failed_login');

-- Tenant deployment model
CREATE TYPE deployment_model AS ENUM ('saas_shared', 'saas_dedicated', 'private_cloud', 'on_premise');
