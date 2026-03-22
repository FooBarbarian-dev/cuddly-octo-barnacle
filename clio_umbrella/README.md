# CLIO - Red Team Logging & DFIR Platform

CLIO is an Elixir/Phoenix umbrella application for capturing, organizing, analyzing, and exporting red team operations data. It provides forensic-grade audit trails, encrypted storage, relationship analysis, and a comprehensive REST API.

## Architecture

```
clio_umbrella/
  apps/
    clio/            # Core domain: schemas, contexts, auth, audit
    clio_web/        # Phoenix API: controllers, plugs, router
    clio_relations/  # Relationship analysis engine
```

### Core Features

- **Log Management** - CRUD with row-level locking, duplicate detection (5-second window), and operation-scoped filtering
- **Tagging System** - Categorized tags (technique, tool, target, status, etc.) with autocomplete and usage stats
- **Operations** - Campaign management with user assignment, primary operation selection, and auto-tagging
- **Evidence Files** - Upload/download with MD5 hashing, MIME validation, and 10MB limit
- **Templates** - Reusable log entry templates
- **Export** - CSV and JSON export with operation-scoped filtering
- **Relationship Analysis** - Tag co-occurrence detection, pattern analysis (runs every 15 min)
- **Audit Trail** - Category-based JSON audit logs (security, data, system, audit) with automatic rotation

### Security

| Layer | Implementation |
|-------|----------------|
| Authentication | PBKDF2-HMAC-SHA256 (310k iterations), JWT (HS256) with Redis-backed revocation |
| Field Encryption | Cloak AES-GCM for sensitive database fields |
| Redis Encryption | AES-256-GCM for all cached values |
| Admin Verification | HMAC-SHA256 admin proof on login |
| Input Sanitization | XSS prevention, IP/MAC/username validation |
| Rate Limiting | Hammer-based per-IP rate limiting (100 req/min general, 10 req/min auth) |
| Audit | Automatic sensitive data redaction, comprehensive event logging |
| Password Policy | 12-128 chars, mixed case, digit, special char, no SQL/XSS patterns |

## Quick Start

### Prerequisites

- Elixir >= 1.14
- Erlang/OTP >= 25
- PostgreSQL >= 14
- Redis >= 6

### Setup

```bash
# Clone and enter the umbrella
cd clio_umbrella

# Install dependencies
mix deps.get

# Configure environment (see Configuration section)
cp config/dev.exs.example config/dev.exs  # or edit dev.exs directly

# Create and migrate database
mix ecto.setup

# Start the server
mix phx.server
```

The API will be available at `http://localhost:4000/api`.

### Configuration

Set these environment variables (or configure in `config/runtime.exs`):

```bash
# Required
export DATABASE_URL="ecto://postgres:postgres@localhost/clio_dev"
export REDIS_URL="redis://localhost:6379"
export JWT_SECRET="your-secret-key-at-least-32-bytes"
export ADMIN_PASSWORD="initial-admin-password"
export USER_PASSWORD="initial-user-password"
export ADMIN_SECRET="hmac-secret-for-admin-proof"
export CLOAK_KEY="base64-encoded-32-byte-aes-key"
export REDIS_ENCRYPTION_KEY="64-char-hex-string-for-redis-aes"
export SERVER_INSTANCE_ID="unique-server-id"

# Optional
export SECRET_KEY_BASE="phoenix-secret-key-base-64-bytes"
export PORT=4000
export DATA_DIR="data"  # where audit logs are stored
```

### First Steps

**1. Login as admin:**

```bash
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "your-admin-password"}'
```

Response includes a JWT token. Use it for all subsequent requests:

```bash
export TOKEN="eyJ..."
```

**2. Change the default password** (required on first login):

```bash
curl -X PUT http://localhost:4000/api/auth/password \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"current_password": "old-pass", "new_password": "NewSecureP@ss123!"}'
```

**3. Create an operation:**

```bash
curl -X POST http://localhost:4000/api/operations \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"operation": {"name": "Thunderstrike", "description": "Q1 engagement"}}'
```

**4. Create a log entry:**

```bash
curl -X POST http://localhost:4000/api/logs \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"log": {
    "hostname": "DC01",
    "internal_ip": "10.0.0.5",
    "username": "CORP\\admin",
    "command": "whoami /all",
    "notes": "Initial recon on domain controller"
  }}'
```

**5. Tag a log entry:**

```bash
# Create a tag
curl -X POST http://localhost:4000/api/tags \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"tag": {"name": "recon", "category": "technique", "color": "#3B82F6"}}'

# Add tag to log
curl -X POST http://localhost:4000/api/logs/1/tags/1 \
  -H "Authorization: Bearer $TOKEN"
```

**6. Export data:**

```bash
# CSV export
curl http://localhost:4000/api/export/csv \
  -H "Authorization: Bearer $TOKEN" \
  -o export.csv

# JSON export
curl http://localhost:4000/api/export/json \
  -H "Authorization: Bearer $TOKEN" \
  -o export.json
```

## API Reference

All endpoints return JSON. Authentication via `Authorization: Bearer <token>` header.

### Authentication

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/auth/login` | Login with username/password |
| `GET` | `/api/auth/verify` | Verify current token |
| `POST` | `/api/auth/logout` | Revoke current token |
| `PUT` | `/api/auth/password` | Change password |

### Logs

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/logs` | List logs (filterable) |
| `GET` | `/api/logs/:id` | Get single log |
| `POST` | `/api/logs` | Create log |
| `PUT` | `/api/logs/:id` | Update log |
| `DELETE` | `/api/logs/:id` | Delete log (admin) |
| `POST` | `/api/logs/bulk-delete` | Bulk delete (admin) |
| `POST` | `/api/logs/:id/lock` | Lock log for editing |
| `POST` | `/api/logs/:id/unlock` | Unlock log |

**Query parameters for `GET /api/logs`:**

| Param | Description |
|-------|-------------|
| `hostname` | Filter by hostname (partial match) |
| `internal_ip` | Filter by internal IP (exact match) |
| `command` | Filter by command (partial match) |
| `username` | Filter by username (partial match) |
| `dateFrom` | Filter by start date (ISO 8601) |
| `dateTo` | Filter by end date (ISO 8601) |
| `limit` | Max results (default: 100) |

### Tags

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/tags` | List all tags |
| `GET` | `/api/tags/:id` | Get single tag |
| `POST` | `/api/tags` | Create tag |
| `PUT` | `/api/tags/:id` | Update tag |
| `DELETE` | `/api/tags/:id` | Delete tag |
| `GET` | `/api/tags/search/autocomplete?q=term` | Autocomplete search |
| `GET` | `/api/tags/stats/usage` | Tag usage statistics |
| `POST` | `/api/logs/:log_id/tags/:tag_id` | Add tag to log |
| `DELETE` | `/api/logs/:log_id/tags/:tag_id` | Remove tag from log |

**Tag categories:** `technique`, `tool`, `target`, `status`, `priority`, `workflow`, `evidence`, `security`, `operation`, `custom`

### Operations

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/operations` | List all operations |
| `GET` | `/api/operations/:id` | Get single operation |
| `POST` | `/api/operations` | Create operation |
| `PUT` | `/api/operations/:id` | Update operation |
| `DELETE` | `/api/operations/:id` | Delete operation |
| `GET` | `/api/operations/mine/list` | My assigned operations |
| `POST` | `/api/operations/:id/assign` | Assign user to operation |
| `DELETE` | `/api/operations/:id/assign/:username` | Unassign user |
| `POST` | `/api/operations/:id/activate` | Set as active operation |

### Templates

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/templates` | List templates |
| `GET` | `/api/templates/:id` | Get template |
| `POST` | `/api/templates` | Create template |
| `PUT` | `/api/templates/:id` | Update template |
| `DELETE` | `/api/templates/:id` | Delete template |

### Evidence

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/logs/:log_id/evidence` | List evidence files for log |
| `POST` | `/api/logs/:log_id/evidence` | Upload evidence file |
| `GET` | `/api/evidence/:id/download` | Download evidence file |
| `DELETE` | `/api/evidence/:id` | Delete evidence file |

**Allowed file types:** JPEG, PNG, GIF, PDF, plain text, PCAP, binary (max 10MB)

### Export

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/export/csv` | Export logs as CSV |
| `GET` | `/api/export/json` | Export logs as JSON |

### Admin Only

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/admin/api-keys` | List API keys |
| `POST` | `/api/admin/api-keys` | Create API key |
| `POST` | `/api/admin/api-keys/:id/revoke` | Revoke API key |
| `GET` | `/api/admin/audit/:category` | View audit logs |

**Audit categories:** `security`, `data`, `system`, `audit`

### Health

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/health` | Health check (public) |

## HTTP Status Codes

| Code | Meaning |
|------|---------|
| `200` | Success |
| `201` | Created |
| `400` | Bad request / invalid input |
| `401` | Unauthorized / invalid token |
| `403` | Forbidden / insufficient permissions |
| `404` | Not found |
| `409` | Conflict (duplicate log entry) |
| `422` | Validation error |
| `423` | Locked (log locked by another user) |
| `429` | Rate limited |

## Data Model

```
operations ──has_many──> user_operations (username, is_primary)
     │
     └── belongs_to ──> tags
                          │
logs ──has_many──> log_tags ──belongs_to──> tags
  │
  └──has_many──> evidence_files

tags ──> tag_relationships (co-occurrence analysis)
```

## Background Workers

| Worker | Interval | Purpose |
|--------|----------|---------|
| `LockReaper` | 5 min | Unlocks stale row locks (30-min TTL) |
| `RotationScheduler` | 1 hour | Rotates audit log files (10k entry limit) |
| `Relations.Coordinator` | 15 min | Analyzes tag co-occurrence patterns |
| `Relations.Cache` | 1 min cleanup | ETS cache with 5-min TTL for relation data |
| `Audit.Writer` | On-demand | Serializes audit events to JSON files |

## Testing

```bash
# Run all tests
mix test

# Run specific app tests
cd apps/clio && mix test
cd apps/clio_web && mix test

# Run with verbose output
mix test --trace
```

Test coverage includes:
- Schema validations (Log, Tag, Operation, ApiKey, EvidenceFile, LogTemplate)
- Context integration tests (Logs, Tags, Operations with full CRUD + edge cases)
- Auth module (password policy, hashing, admin proof, token refresh logic)
- Sanitizer (XSS prevention, IP/MAC validation, shell field handling)
- Audit.Writer (sensitive data redaction)
- Controller/plug tests (routing, admin access, error responses)
- GenServer tests (Relations.Cache)

## Development

```bash
# Start with IEx shell
iex -S mix phx.server

# Run database migrations
mix ecto.migrate

# Reset database
mix ecto.reset

# Generate a migration
mix ecto.gen.migration migration_name
```

## License

Proprietary - Internal use only.
