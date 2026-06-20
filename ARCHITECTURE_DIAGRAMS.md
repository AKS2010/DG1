# GRC Intelligence Platform - Architecture & Workflow Diagrams

## 1. System Architecture Overview

```mermaid
graph TB
    subgraph "Client Layer"
        FE["Next.js Frontend<br/>React UI"]
        Browser["Browser"]
    end

    subgraph "API Gateway & Load Balancing"
        LB["Load Balancer<br/>HTTPS/TLS"]
    end

    subgraph "Backend Application Layer"
        FastAPI["FastAPI Server<br/>v0.1.0"]
        
        subgraph "Middleware Stack"
            AuditMW["Request Audit Middleware<br/>- Method, Path, User<br/>- Timestamp, Status"]
            AuthMW["Authentication Middleware<br/>- JWT/SSO/LDAP<br/>- Tenant Isolation"]
        end

        subgraph "API Router"
            HealthAPI["Health Router<br/>/health"]
            AuthAPI["Auth Router<br/>/auth/login<br/>/auth/logout"]
            RiskAPI["Risk Router<br/>/risks<br/>/risks/{id}"]
            UserAPI["User Router<br/>/users<br/>/users/{id}"]
        end

        subgraph "Service Layer"
            RiskService["Risk Service<br/>- Create/Read/Update<br/>- Risk Scoring<br/>- Control Mapping"]
            AuthService["Auth Service<br/>- Credentials<br/>- Token Management<br/>- Role Assignment"]
            UserService["User Service<br/>- User Management<br/>- Permissions<br/>- Tenant Access"]
        end

        subgraph "Data Access Layer"
            SQLAlchemy["SQLAlchemy ORM<br/>- Async Operations<br/>- Query Builder"]
            Deps["Dependency Injection<br/>- DB Session<br/>- Current User<br/>- Tenant Context"]
        end
    end

    subgraph "Data Storage Layer"
        PostgreSQL["PostgreSQL Database<br/>- risks<br/>- controls<br/>- assessments<br/>- users<br/>- audit_logs"]
    end

    subgraph "Audit & Monitoring"
        AuditSink["Azure Blob Audit Sink<br/>- Async Queue<br/>- Batch Processing<br/>- Event Logging"]
        AzureStorage["Azure Storage<br/>Blob Container"]
    end

    subgraph "Configuration & Security"
        Config["Config Manager<br/>- app_env<br/>- log_level<br/>- DB credentials<br/>- Azure settings"]
        Logger["Logging System<br/>- Structured Logs<br/>- Levels: DEBUG/INFO"]
    end

    Browser -->|HTTPS| LB
    LB -->|Route| FastAPI
    FastAPI --> AuditMW
    AuditMW --> AuthMW
    AuthMW -->|Route to Endpoint| HealthAPI
    AuthMW -->|Route to Endpoint| AuthAPI
    AuthMW -->|Route to Endpoint| RiskAPI
    AuthMW -->|Route to Endpoint| UserAPI
    
    HealthAPI -->|Calls| UserService
    AuthAPI -->|Calls| AuthService
    RiskAPI -->|Calls| RiskService
    UserAPI -->|Calls| UserService
    
    RiskService --> Deps
    AuthService --> Deps
    UserService --> Deps
    
    Deps -->|Executes| SQLAlchemy
    SQLAlchemy -->|Query/Persist| PostgreSQL
    
    AuditMW -->|Enqueue Event| AuditSink
    AuthMW -->|Enqueue Event| AuditSink
    AuditSink -->|Batch Upload| AzureStorage
    
    FastAPI -.->|Read Config| Config
    FastAPI -.->|Write Logs| Logger

    FE -->|REST API Calls| LB
```

---

## 2. Backend Request Processing Workflow

```mermaid
graph TD
    A["Client HTTP Request<br/>POST /api/v1/risks<br/>Headers: Auth Token"]
    
    B["FastAPI Router<br/>Receives Request"]
    
    C["RequestAuditMiddleware<br/>- Extract: Method, Path<br/>- Extract: Query Params<br/>- Record: Timestamp<br/>- Record: User Context"]
    
    D["Authentication Check<br/>- Validate JWT Token<br/>- Extract: tenant_id<br/>- Extract: user_id<br/>- Extract: roles"]
    
    E{Auth Valid?}
    
    E -->|No| F["401 Unauthorized<br/>Return Error"]
    E -->|Yes| G["Dependency Injection<br/>Resolve:<br/>- Current User<br/>- DB Session<br/>- Tenant Context"]
    
    G --> H["Route Dispatcher<br/>Match to Handler<br/>e.g. create_risk"]
    
    H --> I["Service Layer<br/>RiskService.create_risk<br/>- Validate Input<br/>- Generate Risk Code<br/>- Check Tenant Isolation"]
    
    I --> J["Data Access Layer<br/>SQLAlchemy ORM<br/>- Build SQL Query<br/>- Set Defaults<br/>- Add Timestamps"]
    
    J --> K["PostgreSQL Execute<br/>INSERT into risks<br/>- id (UUID)<br/>- tenant_id (FK)<br/>- entity_id (FK)<br/>- risk_code (RSK-001)<br/>- status (draft)"]
    
    K --> L{Insert Success?}
    
    L -->|No| M["IntegrityError<br/>Unique Constraint<br/>Return 409 Conflict"]
    
    L -->|Yes| N["Return Created Risk<br/>- id<br/>- risk_code<br/>- created_at<br/>- created_by"]
    
    N --> O["RequestAuditMiddleware<br/>- Record: Response Status<br/>- Record: Response Time<br/>- Enqueue Audit Event"]
    
    O --> P["Audit Event to Queue<br/>AuditSink.enqueue<br/>Max Size: 10000"]
    
    P --> Q{Background Task}
    
    Q -->|Batch Ready or<br/>Timeout 2s| R["Batch Upload to Azure<br/>Azure Blob Storage<br/>Audit Log Container"]
    
    R --> S["Return Response<br/>HTTP 201 Created<br/>With Location Header"]
    
    F --> T["Response to Client<br/>Error Details"]
    M --> T
    S --> T

    style A fill:#e1f5ff
    style B fill:#e1f5ff
    style C fill:#fff3e0
    style D fill:#fff3e0
    style E fill:#ffe0b2
    style G fill:#f3e5f5
    style H fill:#f3e5f5
    style I fill:#e8f5e9
    style J fill:#e8f5e9
    style K fill:#c8e6c9
    style L fill:#ffe0b2
    style N fill:#e1f5ff
    style O fill:#fff3e0
    style P fill:#fff3e0
    style Q fill:#fce4ec
    style R fill:#fce4ec
    style S fill:#e1f5ff
```

---

## 3. Multi-Tenant Data Isolation Workflow

```mermaid
graph LR
    A["User Login<br/>tenant: ACME<br/>user_id: u123"]
    
    B["Authentication Service<br/>Verify Credentials<br/>Lookup Tenant"]
    
    C["Generate JWT Token<br/>Claims:<br/>- sub: user_id<br/>- tenant_id: t456<br/>- roles: [admin]<br/>- exp: timestamp"]
    
    D["Client Stores Token<br/>Authorization Header"]
    
    E["API Request<br/>GET /api/v1/risks<br/>Bearer: JWT_TOKEN"]
    
    F["Extract Tenant ID<br/>from JWT Claims"]
    
    G{Tenant Context<br/>Established?}
    
    G -->|No| H["Reject Request<br/>403 Forbidden"]
    
    G -->|Yes| I["SQL Query Built<br/>WHERE tenant_id = t456<br/>AND is_deleted = False"]
    
    I --> J["Database Isolation<br/>PostgreSQL Query<br/>Only ACME's risks returned"]
    
    J --> K["Another User<br/>tenant: GLOBEX<br/>user_id: u789"]
    
    K --> L["Same Endpoint<br/>GET /api/v1/risks<br/>Bearer: JWT_TOKEN2"]
    
    L --> M["Extract Tenant ID<br/>from JWT Claims<br/>tenant_id: t999"]
    
    M --> N["Different Context<br/>WHERE tenant_id = t999"]
    
    N --> O["Different Results<br/>Only GLOBEX's risks"]
    
    H -.->|No Cross-Tenant<br/>Data Access| O

    style A fill:#e1f5ff
    style B fill:#fff3e0
    style C fill:#f3e5f5
    style D fill:#e8f5e9
    style E fill:#e1f5ff
    style F fill:#fff3e0
    style G fill:#ffe0b2
    style H fill:#ffcdd2
    style I fill:#e8f5e9
    style J fill:#c8e6c9
    style K fill:#e1f5ff
    style L fill:#e1f5ff
    style M fill:#fff3e0
    style N fill:#e8f5e9
    style O fill:#c8e6c9
```

---

## 4. Risk Management Data Governance Workflow

```mermaid
graph TB
    subgraph "Risk Creation & Governance"
        A["Risk Identification<br/>- Process Owner<br/>- Risk Category<br/>- Risk Type"]
        
        B["Create Risk Record<br/>Service: RiskService<br/>- Generate Risk Code<br/>- Set Inherent Score<br/>- Link Controls"]
        
        C["Risk Status: DRAFT<br/>Fields:<br/>- risk_code: RSK-001<br/>- status: draft<br/>- created_by: user_id<br/>- created_at: timestamp"]
    end

    subgraph "Risk Assessment"
        D["Assess Risk<br/>- Inherent Likelihood<br/>- Inherent Impact<br/>- Calculate Score"]
        
        E["Review & Approve<br/>Maker-Checker<br/>- Reviewer validates<br/>- Sets status: approved"]
        
        F["Risk Status: APPROVED<br/>- inherent_score<br/>- reviewed_by: reviewer_id<br/>- reviewed_at: timestamp"]
    end

    subgraph "Control Mapping & Testing"
        G["Map Controls<br/>Link risks to controls<br/>- Select Control<br/>- Define Effectiveness"]
        
        H["Conduct Control Test<br/>- Test Evidence<br/>- Test Date<br/>- Evaluator"]
        
        I["Assess Effectiveness<br/>- Design Effective?<br/>- Operating Effective?<br/>- Calculate Residual Score"]
    end

    subgraph "Risk Monitoring"
        J["Calculate Residual Risk<br/>Service Logic:<br/>- Residual Likelihood<br/>- Residual Impact<br/>- Residual Score"]
        
        K["Generate Risk Heatmap<br/>Dashboard Widget:<br/>- Likelihood vs Impact<br/>- Color Coded"]
        
        L["Trigger Alerts<br/>- Score Threshold Breach<br/>- Test Due<br/>- Overdue Action"]
    end

    subgraph "Action Management"
        M["Create Mitigation Action<br/>- Owner: manager_id<br/>- Due Date: target_date<br/>- Priority: HIGH/MED/LOW<br/>- Status: open"]
        
        N["Track Action Progress<br/>- Update Status<br/>- Add Evidence<br/>- Track Completion"]
        
        O["Close Action<br/>- Evidence Reviewed<br/>- Status: closed<br/>- closed_at: timestamp"]
    end

    subgraph "Audit & Compliance"
        P["Audit Trail Capture<br/>All Changes Logged:<br/>- Who: user_id<br/>- What: field + old/new value<br/>- When: timestamp<br/>- Why: action_type"]
        
        Q["Compliance Reporting<br/>Export Reports:<br/>- Risk Register PDF<br/>- Control Status<br/>- Open Actions"]
        
        R["Archive Closed Risks<br/>- Status: closed/archived<br/>- Retain History<br/>- Soft Delete: is_deleted"]
    end

    A --> B
    B --> C
    C --> D
    D --> E
    E --> F
    F --> G
    G --> H
    H --> I
    I --> J
    J --> K
    K --> L
    L --> M
    M --> N
    N --> O
    O --> P
    D -.->|Parallel| P
    E -.->|Parallel| P
    H -.->|Parallel| P
    P --> Q
    Q --> R

    style A fill:#e3f2fd
    style B fill:#fff3e0
    style C fill:#c8e6c9
    style D fill:#e3f2fd
    style E fill:#f3e5f5
    style F fill:#c8e6c9
    style G fill:#e3f2fd
    style H fill:#e3f2fd
    style I fill:#e3f2fd
    style J fill:#fff3e0
    style K fill:#f3e5f5
    style L fill:#ffcdd2
    style M fill:#e3f2fd
    style N fill:#fff3e0
    style O fill:#c8e6c9
    style P fill:#ffe0b2
    style Q fill:#f3e5f5
    style R fill:#c8e6c9
```

---

## 5. Backend Data Flow: Risk Service Operations

```mermaid
graph TD
    subgraph "Create Risk"
        C1["RiskService.create_risk<br/>Input: RiskCreate<br/>- title<br/>- description<br/>- risk_type<br/>- category"]
        
        C2["Generate Risk Code<br/>_next_risk_code<br/>Query: SELECT MAX<br/>FROM risks<br/>WHERE risk_code LIKE RSK-%"]
        
        C3["Prepare Risk Object<br/>- id: uuid.uuid4<br/>- tenant_id: from context<br/>- entity_id: from context<br/>- risk_code: RSK-001<br/>- created_at: now<br/>- created_by: actor_id<br/>- status: draft"]
        
        C4["Persist to Database<br/>session.add(risk)<br/>session.flush<br/>session.commit"]
        
        C5["Return: Risk Object<br/>with all fields populated"]
    end

    subgraph "List Risks"
        L1["RiskService.list_risks<br/>Input: tenant_id, page, page_size"]
        
        L2["Build Base Query<br/>SELECT * FROM risks<br/>WHERE tenant_id = ?<br/>AND is_deleted = False"]
        
        L3["Get Total Count<br/>SELECT COUNT<br/>For pagination info"]
        
        L4["Apply Pagination<br/>OFFSET: (page-1) * size<br/>LIMIT: page_size<br/>ORDER BY: created_at DESC"]
        
        L5["Execute Query<br/>Return: list[Risk], total_count"]
    end

    subgraph "Get Single Risk"
        G1["RiskService.get_risk<br/>Input: tenant_id, risk_id"]
        
        G2["Build Query<br/>WHERE id = risk_id<br/>AND tenant_id = tenant_id<br/>AND is_deleted = False"]
        
        G3["Execute Query<br/>Return: Risk | None"]
    end

    subgraph "Update Risk"
        U1["RiskService.update_risk<br/>Input: RiskUpdate<br/>- Only provided fields"]
        
        U2["Fetch Existing Risk<br/>Validate ownership<br/>Check tenant_id"]
        
        U3["Apply Updates<br/>Update only non-null fields<br/>- title, description<br/>- likelihood, impact<br/>- status"]
        
        U4["Update Metadata<br/>- updated_at: now<br/>- updated_by: actor_id"]
        
        U5["Persist Changes<br/>session.add<br/>session.commit"]
    end

    subgraph "Delete Risk - Soft Delete"
        D1["RiskService.delete_risk<br/>Input: tenant_id, risk_id"]
        
        D2["Fetch & Validate Risk<br/>Check ownership<br/>Check tenant_id"]
        
        D3["Soft Delete<br/>is_deleted: True<br/>deleted_at: now<br/>deleted_by: actor_id"]
        
        D4["Commit Changes<br/>Risk still in DB<br/>Filtered by is_deleted in queries"]
    end

    C1 --> C2
    C2 --> C3
    C3 --> C4
    C4 --> C5
    
    L1 --> L2
    L2 --> L3
    L3 --> L4
    L4 --> L5
    
    G1 --> G2
    G2 --> G3
    
    U1 --> U2
    U2 --> U3
    U3 --> U4
    U4 --> U5
    
    D1 --> D2
    D2 --> D3
    D3 --> D4

    style C1 fill:#e3f2fd
    style C2 fill:#fff3e0
    style C3 fill:#f3e5f5
    style C4 fill:#e8f5e9
    style C5 fill:#c8e6c9
    
    style L1 fill:#e3f2fd
    style L2 fill:#fff3e0
    style L3 fill:#fff3e0
    style L4 fill:#f3e5f5
    style L5 fill:#c8e6c9
    
    style G1 fill:#e3f2fd
    style G2 fill:#fff3e0
    style G3 fill:#c8e6c9
    
    style U1 fill:#e3f2fd
    style U2 fill:#fff3e0
    style U3 fill:#f3e5f5
    style U4 fill:#f3e5f5
    style U5 fill:#e8f5e9
    
    style D1 fill:#e3f2fd
    style D2 fill:#fff3e0
    style D3 fill:#ffcdd2
    style D4 fill:#e8f5e9
```

---

## 6. Audit Trail & Compliance Workflow

```mermaid
graph TB
    subgraph "Event Capture"
        E1["Request Audit Middleware<br/>Captures:<br/>- method, path<br/>- query params<br/>- user_id<br/>- tenant_id<br/>- timestamp<br/>- response status"]
    end

    subgraph "Event Queue"
        E2["Async Queue<br/>Max Size: 10,000<br/>Drop on Overflow<br/>to Protect Latency"]
    end

    subgraph "Batch Processing"
        E3["Background Task<br/>Condition 1:<br/>Queue Has Events<br/><br/>Condition 2:<br/>Timeout 2 seconds"]
        
        E4["Build Batch<br/>Group Events<br/>Serialize to JSON"]
    end

    subgraph "Persistence"
        E5["Azure Blob Upload<br/>Container: audit-logs<br/>Blob Name:<br/>audit-{tenant_id}-{date}.log"]
        
        E6["Stored Format<br/>One event per line<br/>JSON format<br/>Immutable storage"]
    end

    subgraph "Retrieval & Reporting"
        E7["Query Audit Logs<br/>Filter by:<br/>- Tenant ID<br/>- Date Range<br/>- Action Type<br/>- User ID"]
        
        E8["Generate Reports<br/>- Access History<br/>- Change History<br/>- Compliance Report"]
    end

    E1 --> E2
    E2 --> E3
    E3 --> E4
    E4 --> E5
    E5 --> E6
    E6 --> E7
    E7 --> E8

    style E1 fill:#fff3e0
    style E2 fill:#f3e5f5
    style E3 fill:#f3e5f5
    style E4 fill:#ffe0b2
    style E5 fill:#fce4ec
    style E6 fill:#fce4ec
    style E7 fill:#c8e6c9
    style E8 fill:#c8e6c9
```

---

## 7. Database Schema - Key Relationships

```mermaid
erDiagram
    TENANTS ||--o{ USERS : has
    TENANTS ||--o{ ENTITIES : has
    TENANTS ||--o{ RISKS : has
    TENANTS ||--o{ CONTROLS : has
    TENANTS ||--o{ ASSESSMENTS : has
    TENANTS ||--o{ COMPLIANCE_ITEMS : has
    
    USERS ||--o{ RISKS : creates
    USERS ||--o{ CONTROLS : creates
    USERS ||--o{ ASSESSMENTS : owns
    
    ENTITIES ||--o{ RISKS : contains
    ENTITIES ||--o{ ASSESSMENTS : has
    
    RISKS ||--o{ CONTROLS : "maps to"
    RISKS ||--o{ ACTIONS : triggers
    RISKS ||--o{ AUDIT_LOGS : "logged as"
    
    CONTROLS ||--o{ CONTROL_TESTS : tested
    CONTROL_TESTS ||--o{ AUDIT_LOGS : "logged as"
    
    ASSESSMENTS ||--o{ QUESTIONS : contains
    ASSESSMENTS ||--o{ FINDINGS : generates
    FINDINGS ||--o{ ACTIONS : creates
    
    COMPLIANCE_ITEMS ||--o{ ACTIONS : triggers
    
    ACTIONS ||--o{ AUDIT_LOGS : "logged as"
    AUDIT_LOGS ||--o{ DOCUMENT_VERSIONS : "attaches"

    TENANTS {
        uuid id PK
        string name
        string slug
        json config
        datetime created_at
    }

    USERS {
        uuid id PK
        uuid tenant_id FK
        string email
        string password_hash
        json roles
        boolean is_active
    }

    ENTITIES {
        uuid id PK
        uuid tenant_id FK
        string name
        string entity_type
    }

    RISKS {
        uuid id PK
        uuid tenant_id FK
        uuid entity_id FK
        uuid created_by FK
        string risk_code UK
        string title
        text description
        enum status
        int inherent_likelihood
        int inherent_impact
        int residual_likelihood
        int residual_impact
        datetime created_at
    }

    CONTROLS {
        uuid id PK
        uuid tenant_id FK
        uuid created_by FK
        string control_id UK
        string title
        enum control_type
        enum status
        datetime created_at
    }

    ACTIONS {
        uuid id PK
        uuid tenant_id FK
        uuid owner_id FK
        string title
        enum priority
        enum status
        date due_date
        datetime created_at
    }

    AUDIT_LOGS {
        uuid id PK
        uuid tenant_id FK
        uuid user_id FK
        string action
        string entity_type
        uuid entity_id
        jsonb changes
        datetime created_at
    }
```

---

## Backend Technology Stack Summary

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Framework** | FastAPI | Async REST API framework |
| **ORM** | SQLAlchemy | Async database operations |
| **Database** | PostgreSQL | Multi-tenant data storage with JSON/ARRAY support |
| **Authentication** | JWT/SSO/LDAP | Secure tenant isolation |
| **Middleware** | RequestAuditMiddleware | Request/response logging |
| **Audit Storage** | Azure Blob Storage | Immutable event log storage |
| **Dependency Injection** | FastAPI Depends | Request scoping, context management |
| **Config** | Pydantic Settings | Environment-based configuration |
| **Logging** | Python logging | Structured logging |
| **Deployment** | Multi-tenant SaaS | Cloud-ready architecture |

---

## Data Governance Principles Implemented

1. **Multi-Tenant Isolation**: Tenant ID enforcement at every query layer
2. **Audit Trail**: Complete change history via RequestAuditMiddleware
3. **Soft Deletes**: Data retention via `is_deleted` flag
4. **Maker-Checker**: Approval workflows for sensitive operations
5. **Role-Based Access**: JWT claims drive authorization
6. **Immutable Audit Logs**: Azure Blob storage for compliance
7. **Timestamp Tracking**: created_at, updated_at, deleted_at on all records
8. **Change Logging**: Actor ID + timestamp on every modification

