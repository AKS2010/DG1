-- ============================================================================
-- eNFeNITE GRC Intelligence Platform - PostgreSQL Schema
-- Module: Document & Evidence Library
-- Features: Version Control, Tagging, Linking, Approval Workflow, Search
-- ============================================================================

-- ============================================================================
-- DOCUMENTS (Policies, SOPs, Templates, etc.)
-- ============================================================================

CREATE TABLE documents (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    entity_id               UUID REFERENCES entities(id),         -- NULL = org-wide
    
    document_code           VARCHAR(100) NOT NULL,
    document_title          VARCHAR(500) NOT NULL,
    document_type           document_type NOT NULL,
    category                VARCHAR(200),
    sub_category            VARCHAR(200),
    
    -- Content
    content_type            VARCHAR(50) NOT NULL,     -- 'file', 'rich_text', 'link'
    rich_text_content       TEXT,                     -- for inline rich text documents
    external_url            VARCHAR(1000),            -- for hyperlinks
    
    -- Current version info
    current_version_id      UUID,                     -- FK added after document_versions is created
    current_version_number  VARCHAR(20) DEFAULT '1.0',
    
    -- Classification & Access
    confidentiality_level   VARCHAR(50) NOT NULL DEFAULT 'internal', -- 'public', 'internal', 'confidential', 'restricted'
    department              VARCHAR(200),
    
    -- Ownership
    document_owner_id       UUID NOT NULL REFERENCES users(id),
    custodian_id            UUID REFERENCES users(id),
    
    -- Review
    review_frequency        frequency_type,
    last_review_date        DATE,
    next_review_date        DATE,
    
    -- Approval
    status                  lifecycle_status NOT NULL DEFAULT 'draft',
    approved_by             UUID REFERENCES users(id),
    approved_at             TIMESTAMPTZ,
    effective_date          DATE,
    expiry_date             DATE,
    
    -- Search & Tags
    tags                    TEXT[] DEFAULT '{}',
    search_vector           TSVECTOR,                 -- for full-text search
    
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID NOT NULL REFERENCES users(id),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID REFERENCES users(id),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at              TIMESTAMPTZ,
    
    UNIQUE(tenant_id, document_code)
);

CREATE INDEX idx_documents_tenant ON documents(tenant_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_documents_entity ON documents(tenant_id, entity_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_documents_type ON documents(tenant_id, document_type) WHERE is_deleted = FALSE;
CREATE INDEX idx_documents_owner ON documents(document_owner_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_documents_status ON documents(tenant_id, status) WHERE is_deleted = FALSE;
CREATE INDEX idx_documents_next_review ON documents(next_review_date) WHERE is_deleted = FALSE AND status = 'active';
CREATE INDEX idx_documents_search ON documents USING GIN (search_vector) WHERE is_deleted = FALSE;
CREATE INDEX idx_documents_tags ON documents USING GIN (tags) WHERE is_deleted = FALSE;
CREATE INDEX idx_documents_confidentiality ON documents(tenant_id, confidentiality_level) WHERE is_deleted = FALSE;

-- ============================================================================
-- DOCUMENT VERSIONS
-- ============================================================================

CREATE TABLE document_versions (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id             UUID NOT NULL REFERENCES documents(id),
    
    version_number          VARCHAR(20) NOT NULL,     -- '1.0', '1.1', '2.0'
    version_label           VARCHAR(200),             -- 'Initial Draft', 'Post-Review Update'
    
    -- File storage
    file_name               VARCHAR(500),
    file_size_bytes         BIGINT,
    file_mime_type          VARCHAR(200),
    file_hash               VARCHAR(128),             -- SHA-256 for integrity
    storage_path            VARCHAR(1000) NOT NULL,   -- secure storage location (S3 key or local path)
    
    -- Content (for rich text versions)
    rich_text_content       TEXT,
    
    -- Change info
    change_description      TEXT,
    change_type             VARCHAR(50),              -- 'major', 'minor', 'patch'
    
    -- Approval
    is_approved             BOOLEAN NOT NULL DEFAULT FALSE,
    approved_by             UUID REFERENCES users(id),
    approved_at             TIMESTAMPTZ,
    
    -- Metadata
    uploaded_by             UUID NOT NULL REFERENCES users(id),
    uploaded_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    is_current              BOOLEAN NOT NULL DEFAULT FALSE,
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    
    UNIQUE(document_id, version_number)
);

CREATE INDEX idx_doc_versions_document ON document_versions(document_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_doc_versions_current ON document_versions(document_id, is_current) WHERE is_current = TRUE AND is_deleted = FALSE;

-- Add FK for current_version_id on documents table
ALTER TABLE documents 
    ADD CONSTRAINT fk_documents_current_version 
    FOREIGN KEY (current_version_id) REFERENCES document_versions(id);

-- ============================================================================
-- EVIDENCE RECORDS (Attachments linked to any GRC object)
-- ============================================================================

CREATE TABLE evidence_records (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    entity_id               UUID REFERENCES entities(id),
    
    evidence_code           VARCHAR(100),
    evidence_title          VARCHAR(500) NOT NULL,
    description             TEXT,
    
    -- File
    file_name               VARCHAR(500) NOT NULL,
    file_size_bytes         BIGINT,
    file_mime_type          VARCHAR(200),
    file_hash               VARCHAR(128),
    storage_path            VARCHAR(1000) NOT NULL,
    
    -- Classification
    evidence_type           VARCHAR(100),             -- 'screenshot', 'report', 'email', 'certificate', 'log_extract', 'approval', 'other'
    confidentiality_level   VARCHAR(50) NOT NULL DEFAULT 'internal',
    
    -- Period
    evidence_date           DATE,
    period_id               UUID REFERENCES financial_periods(id),
    
    -- Approval
    is_verified             BOOLEAN NOT NULL DEFAULT FALSE,
    verified_by             UUID REFERENCES users(id),
    verified_at             TIMESTAMPTZ,
    
    -- Access control
    restricted_access       BOOLEAN NOT NULL DEFAULT FALSE,  -- if true, only linked object owners can view
    
    tags                    TEXT[] DEFAULT '{}',
    custom_attributes       JSONB DEFAULT '{}',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID NOT NULL REFERENCES users(id),
    modified_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_by             UUID REFERENCES users(id),
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at              TIMESTAMPTZ
);

CREATE INDEX idx_evidence_records_tenant ON evidence_records(tenant_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_evidence_records_entity ON evidence_records(tenant_id, entity_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_evidence_records_tags ON evidence_records USING GIN (tags) WHERE is_deleted = FALSE;

-- ============================================================================
-- EVIDENCE LINKING (Polymorphic linking evidence to any GRC object)
-- ============================================================================

CREATE TABLE evidence_links (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    evidence_id             UUID NOT NULL REFERENCES evidence_records(id),
    
    -- Polymorphic link
    linked_object_type      VARCHAR(100) NOT NULL,    -- 'risk', 'control', 'finding', 'assessment', 'compliance_item', 'control_test', 'incident', 'action'
    linked_object_id        UUID NOT NULL,
    
    link_description        TEXT,
    linked_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    linked_by               UUID NOT NULL REFERENCES users(id),
    
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE(evidence_id, linked_object_type, linked_object_id)
);

CREATE INDEX idx_evidence_links_evidence ON evidence_links(evidence_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_evidence_links_object ON evidence_links(linked_object_type, linked_object_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_evidence_links_tenant ON evidence_links(tenant_id) WHERE is_deleted = FALSE;

-- ============================================================================
-- DOCUMENT LINKING (Link documents to GRC objects)
-- ============================================================================

CREATE TABLE document_links (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id               UUID NOT NULL REFERENCES tenants(id),
    document_id             UUID NOT NULL REFERENCES documents(id),
    
    -- Polymorphic link
    linked_object_type      VARCHAR(100) NOT NULL,
    linked_object_id        UUID NOT NULL,
    
    link_purpose            VARCHAR(200),             -- 'reference', 'governing_policy', 'evidence', 'template'
    linked_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    linked_by               UUID NOT NULL REFERENCES users(id),
    
    is_deleted              BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE(document_id, linked_object_type, linked_object_id)
);

CREATE INDEX idx_document_links_document ON document_links(document_id) WHERE is_deleted = FALSE;
CREATE INDEX idx_document_links_object ON document_links(linked_object_type, linked_object_id) WHERE is_deleted = FALSE;
