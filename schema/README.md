# eNFeNITE GRC Intelligence Platform - Database Architecture

## Schema Overview

| # | File | Module | Tables |
|---|------|--------|--------|
| 00 | `00_extensions_and_types.sql` | Extensions & Enums | PostgreSQL extensions, all enumerated types |
| 01 | `01_admin_and_core.sql` | Admin & Core Platform | tenants, entities, financial_periods, users, roles, modules, sub_modules, permissions, role_permissions, user_roles, user_entity_access, user_sessions, password_policies, master_configurations, audit_logs, notification_settings, upload_templates, data_imports, mapping_rules |
| 02 | `02_risk_and_controls.sql` | Risk & Controls | risks, risk_assessments, controls, risk_control_mappings, control_tests, treatment_plans, incidents |
| 03 | `03_assessments_and_audit.sql` | Assessments & Audit | frameworks, framework_domains, framework_requirements, assessment_plans, assessment_team_members, questionnaires, questions, assessment_responses, findings, pbc_queries |
| 04 | `04_compliance_obligations.sql` | Compliance Obligations | compliance_obligations, compliance_calendar_items, regulatory_updates |
| 05 | `05_finance_intelligence.sql` | Finance Intelligence | coa_groups, accounts, trial_balance_entries, financial_transactions, cashflow_entries, kpi_results, finance_alerts |
| 06 | `06_document_evidence_library.sql` | Document & Evidence Library | documents, document_versions, evidence_records, evidence_links, document_links |
| 07 | `07_alerts_actions_reports.sql` | Alerts, Actions & Reports | actions, action_comments, alerts, alert_user_status, alert_rules, report_definitions, report_instances |
| 08 | `08_training.sql` | Training | training_courses, training_assignments |
| 09 | `09_dynamic_columns_strategy.sql` | Dynamic Columns (JSONB + EAV) | custom_field_definitions, custom_field_values, custom_field_audit |
| 10 | `10_rls_security_triggers.sql` | Security & Triggers | RLS policies, encryption functions, auto-triggers |
| 11 | `11_relationships_and_views.sql` | Relationships & Views | Dashboard views, materialized views, notification_queue |

**Total: ~55 tables + views**

---

## Key Architectural Decisions

### 1. Multi-Tenant Data Isolation
- Every data table carries `tenant_id` as the partition key
- PostgreSQL Row-Level Security (RLS) enforces tenant isolation at the database layer
- Application sets `app.current_tenant_id` on each DB connection
- Even if application code has a bug, RLS prevents cross-tenant data leaks

### 2. Dynamic Columns Strategy (Future-Proofing)

**Recommended Hybrid Approach:**

| Approach | When to Use | How |
|----------|-------------|-----|
| **JSONB `custom_attributes`** | Simple key-value extensions, tenant-specific metadata | Already on every table. Index with GIN. No schema change needed. |
| **EAV (custom_field_definitions + custom_field_values)** | Formal tenant-defined fields needing UI rendering, validation, reporting | Define field → Store typed values → Query with JOINs |
| **Schema migration** | When a JSONB field becomes universally needed | ALTER TABLE ADD COLUMN → migrate data → remove from JSONB |

**Why not ALTER TABLE for every custom field?**
- Multi-tenant systems can't have per-tenant columns (table bloat)
- JSONB + EAV gives each tenant their own "virtual columns" without DDL changes
- GIN indexes on JSONB provide excellent query performance

### 3. Security & Data Governance

| Layer | Implementation |
|-------|---------------|
| **Tenant Isolation** | RLS policies on all tables |
| **Authentication** | Local + LDAP/SAML/OAuth2 support, MFA |
| **Password Policy** | Configurable per tenant (length, complexity, age, history) |
| **Session Security** | Hashed tokens, IP tracking, configurable timeout, auto-expiry |
| **Encryption** | pgcrypto for data-at-rest; TLS for transit (infra-level) |
| **Audit Trail** | Immutable `audit_logs` table capturing every CRUD action with user, IP, changes JSONB |
| **Soft Deletes** | `is_deleted` flag + `deleted_at` timestamp; hard DELETE prevented by trigger |
| **Document Access** | Confidentiality levels (public/internal/confidential/restricted) with RLS |
| **Hard Delete Prevention** | Trigger raises exception on DELETE for critical tables |
| **Role-Based Access** | Module → Sub-Module → Action level permissions |
| **Failed Login Tracking** | Counter + auto-lockout per password policy |

### 4. Standard Audit Columns (On every business table)

```sql
created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
created_by    UUID NOT NULL REFERENCES users(id)
modified_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()  -- auto-updated by trigger
modified_by   UUID REFERENCES users(id)
is_deleted    BOOLEAN NOT NULL DEFAULT FALSE
deleted_at    TIMESTAMPTZ
version       INTEGER NOT NULL DEFAULT 1          -- auto-incremented by trigger
```

### 5. Relationship Strategy

- **Direct FK**: Used for strong, always-present relationships (risk → entity, user → tenant)
- **Polymorphic Links**: Used for cross-module references (evidence_links, document_links, actions.source_object_type/id)
- **Junction Tables**: Used for M:N relationships (risk_control_mappings, user_roles, role_permissions)
- **Hierarchical**: Self-referencing FK for tree structures (entities, framework_domains, coa_groups)

---

## Module Relationships Diagram

```
┌──────────────┐     ┌──────────────┐     ┌──────────────────┐
│   TENANTS    │────▶│   ENTITIES   │────▶│ FINANCIAL_PERIODS │
└──────────────┘     └──────┬───────┘     └──────────────────┘
       │                    │
       │              ┌─────┼──────────────────────────┐
       │              │     │                          │
       ▼              ▼     ▼                          ▼
┌──────────┐   ┌──────────┐   ┌────────────────┐  ┌────────────────┐
│  USERS   │   │  RISKS   │   │ ASSESSMENTS    │  │  COMPLIANCE    │
│  ROLES   │   │ CONTROLS │   │ QUESTIONNAIRES │  │  OBLIGATIONS   │
│  PERMS   │   │ INCIDENTS│   │ FINDINGS       │  │  CALENDAR      │
└──────────┘   └────┬─────┘   └───────┬────────┘  └────────────────┘
                    │                  │
                    │    ┌─────────────┤
                    │    │             │
                    ▼    ▼             ▼
              ┌──────────────┐  ┌──────────────┐
              │   ACTIONS    │  │  EVIDENCE    │◀── Polymorphic links
              │   ALERTS     │  │  DOCUMENTS   │    to ALL modules
              └──────────────┘  └──────────────┘
```

---

## Execution Order

Run the SQL files in numbered order (00 → 11). Each file depends only on tables created in previous files.

```bash
psql -d enfenite_grc -f 00_extensions_and_types.sql
psql -d enfenite_grc -f 01_admin_and_core.sql
psql -d enfenite_grc -f 02_risk_and_controls.sql
psql -d enfenite_grc -f 03_assessments_and_audit.sql
psql -d enfenite_grc -f 04_compliance_obligations.sql
psql -d enfenite_grc -f 05_finance_intelligence.sql
psql -d enfenite_grc -f 06_document_evidence_library.sql
psql -d enfenite_grc -f 07_alerts_actions_reports.sql
psql -d enfenite_grc -f 08_training.sql
psql -d enfenite_grc -f 09_dynamic_columns_strategy.sql
psql -d enfenite_grc -f 10_rls_security_triggers.sql
psql -d enfenite_grc -f 11_relationships_and_views.sql
```

---

## Performance Considerations

- **Partial indexes** (`WHERE is_deleted = FALSE`) reduce index size by ~30-50%
- **GIN indexes** on JSONB and arrays for flexible querying
- **Materialized views** for dashboard aggregations (refresh daily)
- **Audit log partitioning** recommended by month for high-volume tenants
- **Connection pooling** (PgBouncer) with tenant_id set via `SET app.current_tenant_id`
- **Computed columns** (`GENERATED ALWAYS AS ... STORED`) for risk scores avoid runtime calculation
