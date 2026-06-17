# DG-API — Data Governance & GRC Intelligence Platform

Multi-tenant REST API for the **eNFeNITE GRC Intelligence Platform**, built with FastAPI, SQLAlchemy (async), and PostgreSQL.

---

## Table of Contents

1. [Tech Stack](#tech-stack)
2. [Project Structure](#project-structure)
3. [Getting Started](#getting-started)
4. [Configuration](#configuration)
5. [Authentication & Authorization](#authentication--authorization)
   - [Password Login](#1-password-login-production)
   - [Developer Token](#2-developer-token-non-prod-only)
   - [JWT Structure](#jwt-token-structure)
   - [Authorization Flow](#authorization-flow)
   - [Permission & Role Guards](#permission--role-guards)
6. [API Reference](#api-reference)
   - [Health](#health)
   - [Auth](#auth)
   - [Users](#users)
   - [Risks](#risks)
7. [Multi-Tenancy](#multi-tenancy)
8. [Audit & Observability](#audit--observability)
9. [Database Schema](#database-schema)
10. [Development Workflow](#development-workflow)

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | FastAPI 0.115+ |
| Language | Python 3.11 |
| ORM | SQLAlchemy 2.x (async) |
| Database | PostgreSQL (asyncpg driver) |
| Auth | RS256 JWT (python-jose + cryptography) |
| Password Hashing | Argon2 (passlib) |
| Settings | pydantic-settings (`.env` file) |
| Logging | structlog (JSON) |
| Audit Sink | Azure Blob Storage (append blobs) |
| Validation | Pydantic v2 |

---

## Project Structure

```
app/
├── main.py                  # FastAPI app, lifespan, middleware
├── api/
│   ├── deps.py              # Auth dependencies (PrincipalContext, guards)
│   ├── router.py            # Route aggregation
│   └── routes/
│       ├── auth.py          # Login, dev-token, /me, public-key, JWKS
│       ├── health.py        # Liveness & readiness probes
│       ├── users.py         # CRUD for users
│       └── risks.py         # CRUD for risks
├── core/
│   ├── config.py            # Settings from environment / .env
│   ├── database.py          # Async engine, session factory
│   ├── security.py          # JWT sign/verify, password hashing, JWKS
│   ├── logging.py           # structlog JSON configuration
│   └── audit_sink.py        # Background Azure Blob audit writer
├── middleware/
│   └── audit.py             # Request audit middleware
├── models/
│   ├── base.py              # SQLAlchemy DeclarativeBase
│   ├── user.py              # User model
│   ├── role.py              # Role, UserRole, Permission, RolePermission
│   └── risk.py              # Risk model
├── schemas/
│   ├── auth.py              # LoginRequest, DevTokenRequest, TokenResponse
│   ├── health.py            # HealthResponse, ReadinessResponse
│   ├── user.py              # UserCreate, UserUpdate, UserRead
│   └── risk.py              # RiskCreate, RiskUpdate, RiskRead
└── services/
    ├── auth_service.py      # Email lookup, role resolution, login tracking
    ├── user_service.py      # User CRUD logic
    └── risk_service.py      # Risk CRUD logic

schema/                      # PostgreSQL DDL scripts (00–11)
```

---

## Getting Started

### Prerequisites

- Python 3.11
- PostgreSQL 13+
- An RSA private key for JWT signing

### Installation

```bash
# Create virtual environment
python -m venv .venv
.venv\Scripts\Activate.ps1        # Windows
# source .venv/bin/activate       # Linux/Mac

# Install dependencies
pip install -e ".[dev]"
```

### Database Setup

Run the SQL files in `schema/` against your PostgreSQL instance in order:

```bash
psql -d your_database -f schema/00_extensions_and_types.sql
psql -d your_database -f schema/01_admin_and_core.sql
# ... through 11_relationships_and_views.sql
```

### Generate RSA Keys (if you don't have one)

```bash
openssl genpkey -algorithm RSA -out jwt_private.pem -pkeyopt rsa_keygen_bits:2048
openssl rsa -in jwt_private.pem -pubout -out jwt_public.pem
```

### Run the Server

```bash
uvicorn app.main:app --port 8003 --reload
```

Swagger UI is available at `http://localhost:8003/docs` (non-prod only).

---

## Configuration

All settings are loaded from environment variables or a `.env` file.

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_NAME` | `dg-api` | Application name |
| `APP_ENV` | `dev` | Environment (`dev`, `staging`, `prod`). Disables Swagger in `prod`. |
| `APP_PORT` | `8000` | Server port |
| `APP_LOG_LEVEL` | `INFO` | Log level |
| `DATABASE_URL` | *(required)* | Async PostgreSQL URL, e.g. `postgresql+asyncpg://user:pass@host/db` |
| `ENABLE_DEV_AUTH` | `true` | Enable `/auth/dev-token` endpoint |
| `JWT_PRIVATE_KEY` | *(required)* | PEM-encoded RSA private key (use `\n` for newlines in env var) |
| `JWT_PUBLIC_KEY` | *(auto-derived)* | PEM-encoded RSA public key. Auto-derived from private key if omitted. |
| `JWT_ALGORITHM` | `RS256` | JWT signing algorithm |
| `JWT_KEY_ID` | `dg-api-key-1` | Key ID in JWT header (`kid`) |
| `JWT_ISSUER` | `dg-api` | JWT `iss` claim |
| `JWT_AUDIENCE` | `dg-spa` | JWT `aud` claim |
| `ACCESS_TOKEN_EXPIRES_MINUTES` | `60` | Token TTL (5–1440 minutes) |
| `AZURE_STORAGE_ACCOUNT_URL` | `null` | Azure Blob URL for audit logs. Disabled if null. |
| `AZURE_STORAGE_CONTAINER` | `api-audit-logs` | Blob container name |

---

## Authentication & Authorization

The API supports two authentication methods, both producing the same JWT format.

### 1. Password Login (Production)

```
POST /api/v1/auth/login
```

```json
{
  "email": "user@company.com",
  "password": "your-password"
}
```

**Flow:**

```
Client                          API Server                        Database
  │                                │                                │
  │  POST /auth/login              │                                │
  │  {email, password}             │                                │
  │  ─────────────────────────────>│                                │
  │                                │  Lookup user by email           │
  │                                │  ──────────────────────────────>│
  │                                │  <──────────────────────────────│
  │                                │                                │
  │                                │  Verify: is_active, !is_locked │
  │                                │  Verify: Argon2(password)      │
  │                                │                                │
  │                                │  Load active role codes        │
  │                                │  ──────────────────────────────>│
  │                                │  <──────────────────────────────│
  │                                │                                │
  │                                │  Sign JWT (RS256 private key)  │
  │                                │  Record successful login       │
  │  <─────────────────────────────│                                │
  │  {access_token, user_id,       │                                │
  │   tenant_id, email, roles}     │                                │
```

**Security checks during login:**
- User must exist (looked up by email)
- `is_active` must be `true` (otherwise → 403)
- `is_locked` must be `false` (otherwise → 403)
- Password verified against Argon2 hash
- Failed login increments `failed_login_count`; account locks after 5 consecutive failures
- Successful login resets `failed_login_count` and updates `last_login_at`

### 2. Developer Token (Non-Prod Only)

```
POST /api/v1/auth/dev-token
```

```json
{
  "actor_id": "00000000-0000-0000-0000-000000000001",
  "tenant_id": "your-tenant-uuid",
  "permissions": ["users.read", "users.write", "risks.read", "risks.write"],
  "expires_in_minutes": 60
}
```

**When available:** Only when `APP_ENV != "prod"` AND `ENABLE_DEV_AUTH == true`.

Dev tokens set `auth_method: "dev_jwt"` in the JWT. Routes using `require_permission()` **bypass permission checks** for dev tokens, giving full access to all endpoints.

### JWT Token Structure

All tokens are RS256-signed JWTs with this payload:

```json
{
  "sub": "user-uuid",
  "user_id": "user-uuid",
  "email": "user@company.com",
  "tenant_id": "tenant-uuid",
  "roles": ["admin", "risk_manager"],
  "permissions": [],
  "auth_method": "password | dev_jwt",
  "iss": "dg-api",
  "aud": "dg-spa",
  "iat": 1718700000,
  "exp": 1718703600
}
```

| Claim | Source |
|-------|--------|
| `sub` | User ID (primary key) |
| `tenant_id` | From user record (password login) or request (dev token) |
| `roles` | Active role codes from `user_roles` + `roles` tables |
| `permissions` | Explicit permissions (dev token only) |
| `auth_method` | `"password"` for login, `"dev_jwt"` for dev tokens |

### Authorization Flow

```
Client Request
    │
    ▼
┌─────────────────────────────┐
│  Extract Bearer token       │
│  (OAuth2PasswordBearer)     │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Decode & verify JWT        │
│  - Algorithm: RS256         │
│  - Issuer: dg-api           │
│  - Audience: dg-spa         │
│  - Check expiration         │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Build PrincipalContext     │
│  - actor_id (from "sub")    │
│  - tenant_id                │
│  - roles                    │
│  - permissions              │
│  - auth_method              │
│  - email                    │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  Check auth_method          │
│  If "dev_jwt" and dev auth  │
│  is disabled → 401          │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│  require_permission() or    │
│  require_role() guard       │
│  - dev_jwt → bypass         │
│  - otherwise → check claim  │
└──────────────┬──────────────┘
               │
               ▼
        Route Handler
  (tenant-scoped DB queries)
```

### Permission & Role Guards

Routes are protected by dependency-injected guards:

```python
# Require a specific permission
@router.get("", dependencies=[Depends(require_permission("users.read"))])

# Require a specific role
@router.get("", dependencies=[Depends(require_role("admin", "auditor"))])
```

**`require_permission(code)`** — checks if `code` is in the JWT's `permissions` set. Dev tokens (`auth_method == "dev_jwt"`) bypass this check entirely.

**`require_role(*codes)`** — checks if any of the given role codes appear in the JWT's `roles` set. No dev-token bypass.

---

## API Reference

All routes are prefixed with `/api/v1`.

### Health

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/health/live` | No | Liveness probe → `{"status": "ok"}` |
| GET | `/health/ready` | No | Readiness probe → checks DB connectivity |

### Auth

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/login` | No | Authenticate with email + password |
| POST | `/auth/dev-token` | No | Generate a dev JWT (non-prod only) |
| GET | `/auth/me` | Bearer | Return current principal from token |
| GET | `/auth/public-key` | No | RSA public key in PEM format |
| GET | `/auth/.well-known/jwks.json` | No | JWKS endpoint for token verification |

### Users

| Method | Path | Permission | Description |
|--------|------|-----------|-------------|
| GET | `/users` | `users.read` | List users (paginated) |
| GET | `/users/{user_id}` | `users.read` | Get user by ID |
| POST | `/users` | `users.write` | Create a user |
| PATCH | `/users/{user_id}` | `users.write` | Update a user |
| DELETE | `/users/{user_id}` | `users.delete` | Soft-delete a user |

### Risks

| Method | Path | Permission | Description |
|--------|------|-----------|-------------|
| GET | `/risks` | `risks.read` | List risks (paginated) |
| GET | `/risks/{risk_id}` | `risks.read` | Get risk by ID |
| POST | `/risks` | `risks.write` | Create a risk |
| PATCH | `/risks/{risk_id}` | `risks.write` | Update a risk |

---

## Multi-Tenancy

The platform uses **row-level tenant isolation**:

- Every business table has a `tenant_id UUID NOT NULL` column.
- All service-layer queries filter by the `tenant_id` extracted from the JWT.
- Cross-tenant write operations are rejected at the route level (e.g., creating a user with a `tenant_id` different from the token's → 403).
- PostgreSQL Row-Level Security (RLS) policies provide a database-level safety net (defined in `schema/10_rls_security_triggers.sql`).

---

## Audit & Observability

### Request Audit Middleware

Every HTTP request is logged as a structured JSON record:

```json
{
  "request_id": "uuid",
  "tenant_id": "uuid",
  "actor_id": "uuid",
  "auth_method": "password",
  "method": "GET",
  "path": "/api/v1/users",
  "query_keys": ["page", "page_size"],
  "status_code": 200,
  "latency_ms": 12.34,
  "client_ip": "127.0.0.1",
  "user_agent": "PostmanRuntime/7.x"
}
```

- Logged to stdout via structlog (JSON format).
- Optionally shipped to **Azure Blob Storage** as NDJSON append blobs, organized by `YYYY/MM/DD/HH/`.
- Every response includes an `X-Request-Id` header for traceability.

### Data Audit Fields

Every business table carries standard audit columns:

| Column | Description |
|--------|-------------|
| `created_at` | Row creation timestamp |
| `created_by` | UUID of the actor who created the row |
| `modified_at` | Last modification timestamp |
| `modified_by` | UUID of the actor who modified the row |
| `is_deleted` | Soft-delete flag |
| `deleted_at` | Deletion timestamp |
| `version` | Optimistic concurrency version counter |

---

## Database Schema

The full schema is defined in 12 SQL files under `schema/`:

| File | Module |
|------|--------|
| `00_extensions_and_types.sql` | PostgreSQL extensions & enum types |
| `01_admin_and_core.sql` | Tenants, entities, users, roles, permissions, master config |
| `02_risk_and_controls.sql` | Risk register, controls, mappings, testing, treatment plans, incidents |
| `03_assessments_and_audit.sql` | Assessments & internal audit |
| `04_compliance_obligations.sql` | Compliance obligations |
| `05_finance_intelligence.sql` | Finance intelligence |
| `06_document_evidence_library.sql` | Document & evidence library |
| `07_alerts_actions_reports.sql` | Alerts, actions, reports |
| `08_training.sql` | Training management |
| `09_dynamic_columns_strategy.sql` | JSONB + EAV dynamic fields |
| `10_rls_security_triggers.sql` | Row-level security & triggers |
| `11_relationships_and_views.sql` | Cross-module views |

Key design decisions:
- **Enum types** for lifecycle status, risk type, control type, frequency, severity, etc.
- **JSONB `custom_attributes`** on every business table for tenant-specific extensions.
- **Soft deletes** everywhere (`is_deleted` flag); hard-delete prevention triggers.
- **GIN indexes** on JSONB and array columns for performant queries.

---

## Development Workflow

### Quick Start with Dev Token

```bash
# 1. Start the server
uvicorn app.main:app --port 8003 --reload

# 2. Get a dev token (Postman or curl)
curl -X POST http://localhost:8003/api/v1/auth/dev-token \
  -H "Content-Type: application/json" \
  -d '{
    "actor_id": "00000000-0000-0000-0000-000000000001",
    "tenant_id": "YOUR-TENANT-UUID",
    "permissions": ["users.read","users.write","users.delete","risks.read","risks.write"]
  }'

# 3. Use the token
curl http://localhost:8003/api/v1/users \
  -H "Authorization: Bearer <token>"
```

### Running Tests

```bash
pytest
```

### Code Quality

```bash
ruff check .      # Linting
mypy app/         # Type checking
```
