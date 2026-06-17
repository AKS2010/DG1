-- ============================================================================
-- eNFeNITE GRC Intelligence Platform - PostgreSQL Schema
-- Module: Dynamic Columns Strategy (JSONB + EAV Hybrid)
-- 
-- STRATEGY OVERVIEW:
-- For handling future dynamic columns, we use a HYBRID approach:
--
-- Option 1: JSONB (custom_attributes column) - RECOMMENDED for most cases
--   Pros: No schema changes, flexible, supports indexing via GIN, fast reads
--   Cons: No strict type enforcement, harder to query complex relationships
--   Best for: Custom metadata, tenant-specific fields, ad-hoc attributes
--
-- Option 2: EAV (Entity-Attribute-Value) - For structured dynamic fields
--   Pros: Type-safe, queryable, can enforce constraints, auditable
--   Cons: More complex queries (pivoting), slightly slower for bulk reads
--   Best for: Configurable forms, tenant-defined scoring, custom field definitions
--
-- RECOMMENDATION:
--   Use JSONB custom_attributes (already on all tables) for simple key-value extensions.
--   Use EAV tables below ONLY when tenants need to define formal custom fields with:
--   - UI form rendering
--   - Validation rules
--   - Reporting/filtering requirements
--   - Audit trail at field level
-- ============================================================================

-- ============================================================================
-- CUSTOM FIELD DEFINITIONS (Tenant-defined dynamic fields)
-- ============================================================================

CREATE TABLE custom_field_definitions (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    
    -- Target
    target_object_type      VARCHAR(100) NOT NULL,    -- 'risk', 'control', 'finding', 'compliance_obligation', 'assessment', 'document', 'action', 'incident'
    
    -- Field definition
    field_code              VARCHAR(100) NOT NULL,
    field_label             VARCHAR(300) NOT NULL,
    field_description       TEXT,
    
    -- Data type
    field_type              VARCHAR(50) NOT NULL,     -- 'text', 'number', 'decimal', 'date', 'datetime', 'boolean', 'dropdown', 'multi_select', 'url', 'email', 'textarea', 'file'
    
    -- Validation
    is_required             BOOLEAN NOT NULL DEFAULT FALSE,
    is_unique               BOOLEAN NOT NULL DEFAULT FALSE,
    min_value               NUMERIC(18,4),
    max_value               NUMERIC(18,4),
    min_length              INTEGER,
    max_length              INTEGER,
    regex_pattern           VARCHAR(500),
    default_value           TEXT,
    
    -- Dropdown options (for dropdown/multi_select types)
    options                 JSONB DEFAULT '[]',       -- [{value: 'opt1', label: 'Option 1', color: '#ff0000'}, ...]
    
    -- UI
    display_order           INTEGER NOT NULL DEFAULT 0,
    section_name            VARCHAR(200),             -- group fields into UI sections
    placeholder_text        VARCHAR(300),
    help_text               TEXT,
    is_visible              BOOLEAN NOT NULL DEFAULT TRUE,
    is_editable             BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Searchability
    is_searchable           BOOLEAN NOT NULL DEFAULT FALSE,
    is_filterable           BOOLEAN NOT NULL DEFAULT FALSE,
    show_in_list_view       BOOLEAN NOT NULL DEFAULT FALSE,
    show_in_reports         BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Scope (can be limited to specific entities)
    applicable_entity_ids   UUID[] DEFAULT '{}',     -- empty = all entities
    
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID NOT NULL REFERENCES users(id),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID REFERENCES users(id),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE(tenant_id, target_object_type, field_code)
);

CREATE INDEX idx_custom_fields_tenant_target ON custom_field_definitions(tenant_id, target_object_type) WHERE is_active = TRUE AND is_deleted = FALSE;

-- ============================================================================
-- CUSTOM FIELD VALUES (EAV storage for defined custom fields)
-- ============================================================================

CREATE TABLE custom_field_values (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    field_definition_id     UUID NOT NULL REFERENCES custom_field_definitions(id),
    
    -- Target object
    object_type             VARCHAR(100) NOT NULL,
    object_id               UUID NOT NULL,
    
    -- Values (store in appropriate column based on field_type)
    value_text              TEXT,
    value_number            NUMERIC(18,4),
    value_boolean           BOOLEAN,
    value_date              DATE,
    value_datetime          TIMESTAMPTZ,
    value_json              JSONB,                    -- for multi_select, complex objects
    
    -- Metadata
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID NOT NULL REFERENCES users(id),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID REFERENCES users(id),
    
    UNIQUE(field_definition_id, object_id)
);

CREATE INDEX idx_custom_field_values_object ON custom_field_values(object_type, object_id);
CREATE INDEX idx_custom_field_values_definition ON custom_field_values(field_definition_id);
CREATE INDEX idx_custom_field_values_tenant ON custom_field_values(tenant_id, object_type);
CREATE INDEX idx_custom_field_values_text ON custom_field_values(value_text) WHERE value_text IS NOT NULL;
CREATE INDEX idx_custom_field_values_number ON custom_field_values(value_number) WHERE value_number IS NOT NULL;
CREATE INDEX idx_custom_field_values_date ON custom_field_values(value_date) WHERE value_date IS NOT NULL;

-- ============================================================================
-- CUSTOM FIELD AUDIT (Track changes to custom field values)
-- ============================================================================

CREATE TABLE custom_field_audit (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    field_definition_id     UUID NOT NULL REFERENCES custom_field_definitions(id),
    object_type             VARCHAR(100) NOT NULL,
    object_id               UUID NOT NULL,
    
    old_value_text          TEXT,
    new_value_text          TEXT,
    old_value_number        NUMERIC(18,4),
    new_value_number        NUMERIC(18,4),
    
    changed_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    changed_by              UUID NOT NULL REFERENCES users(id)
);

CREATE INDEX idx_custom_field_audit_object ON custom_field_audit(object_type, object_id, changed_at DESC);

-- ============================================================================
-- USAGE EXAMPLES AND PATTERNS
-- ============================================================================

/*
-- ============================================================
-- PATTERN 1: Using JSONB custom_attributes (Simple, No Schema Changes)
-- ============================================================

-- Store custom data directly:
UPDATE risks 
SET custom_attributes = custom_attributes || '{"business_unit": "APAC", "risk_appetite_threshold": 15}'::jsonb
WHERE id = '...';

-- Query custom attributes:
SELECT * FROM risks 
WHERE custom_attributes->>'business_unit' = 'APAC';

-- Index specific JSONB paths for frequent queries:
CREATE INDEX idx_risks_custom_bu ON risks ((custom_attributes->>'business_unit')) 
WHERE is_deleted = FALSE;

-- ============================================================
-- PATTERN 2: Using EAV Custom Fields (Formal, UI-Driven)
-- ============================================================

-- Step 1: Admin defines a custom field for the 'risk' object
INSERT INTO custom_field_definitions (tenant_id, target_object_type, field_code, field_label, field_type, is_required, options)
VALUES (
    'tenant-uuid', 'risk', 'industry_vertical', 'Industry Vertical', 'dropdown', true,
    '[{"value": "banking", "label": "Banking"}, {"value": "insurance", "label": "Insurance"}, {"value": "manufacturing", "label": "Manufacturing"}]'
);

-- Step 2: When user fills the form, store the value
INSERT INTO custom_field_values (tenant_id, field_definition_id, object_type, object_id, value_text, created_by)
VALUES ('tenant-uuid', 'field-def-uuid', 'risk', 'risk-uuid', 'banking', 'user-uuid');

-- Step 3: Query with custom fields
SELECT r.*, cfv.value_text AS industry_vertical
FROM risks r
LEFT JOIN custom_field_values cfv ON cfv.object_id = r.id 
    AND cfv.field_definition_id = 'field-def-uuid'
WHERE r.tenant_id = 'tenant-uuid';

-- ============================================================
-- PATTERN 3: Migrating JSONB to formal columns (When needed)
-- ============================================================

-- If a custom_attributes field becomes universally needed:
-- 1. Add the column: ALTER TABLE risks ADD COLUMN business_unit VARCHAR(200);
-- 2. Migrate data: UPDATE risks SET business_unit = custom_attributes->>'business_unit';
-- 3. Remove from JSONB: UPDATE risks SET custom_attributes = custom_attributes - 'business_unit';

*/
