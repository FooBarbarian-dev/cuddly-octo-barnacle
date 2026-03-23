# CLIO - Red Team Logging & DFIR Platform

CLIO is an Elixir/Phoenix umbrella application for capturing, organizing, analyzing, and exporting red team operations data. It provides forensic-grade audit trails, encrypted storage, relationship analysis, and a comprehensive REST API.

## Architecture

```
clio_umbrella/
  apps/
    clio/            # Core domain: schemas, contexts, auth, audit
    clio_web/        # Phoenix web: JSON API + Backpex admin panel
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

> **PoC note:** SSL/TLS and reverse-proxy configuration are intentionally skipped
> to simplify setup. The app runs over plain HTTP. See `.env.example` for a full
> list of what is omitted and what to add before any real deployment.

| Layer | Implementation |
|-------|----------------|
| Authentication | PBKDF2-HMAC-SHA256 (310k iterations), JWT (HS256) with in-memory (Cachex) revocation |
| Field Encryption | Cloak AES-GCM for sensitive database fields |
| Cache Encryption | AES-256-GCM for all cached values |
| Admin Verification | HMAC-SHA256 admin proof on login |
| Input Sanitization | XSS prevention, IP/MAC/username validation |
| Rate Limiting | Hammer-based per-IP rate limiting (100 req/min general, 10 req/min auth) |
| Audit | Automatic sensitive data redaction, comprehensive event logging |
| Password Policy | 12-128 chars, mixed case, digit, special char, no SQL/XSS patterns |
| Transport (SKIPPED) | No TLS — running plain HTTP. Add a reverse proxy with TLS for production. |
| DB Transport (SKIPPED) | No SSL on PostgreSQL connection. Enable `ssl: true` in `runtime.exs` for production. |

## Quick Start

### Prerequisites

**Option 1: Docker (Recommended)**
- Docker >= 20.10
- Docker Compose >= 2.0

**Option 2: Native Installation**
- Elixir >= 1.14
- Erlang/OTP >= 25
- PostgreSQL >= 18 (or >= 14 minimum)

### Docker Setup (Recommended)

Docker is used for PostgreSQL. The application runs natively via `mix`, giving you hot code reloading and easy debugging.

**Option A: Automated first-time setup**

```bash
cd clio_umbrella

# One command does everything: starts postgres, installs deps, migrates, seeds
make dev

# Then start the application
mix phx.server
```

**Option B: Step by step**

```bash
cd clio_umbrella

# 1. Start PostgreSQL (waits until ready)
make up

# 2. Install dependencies
mix deps.get

# 3. Create database, run migrations, and load seed data
mix ecto.setup

# 4. Start the application
mix phx.server
```

**Option C: Automated script (handles all of the above)**

```bash
cd clio_umbrella
./setup.sh
# When complete:
mix phx.server
```

The API will be available at `http://localhost:4000/api`.
The admin panel will be available at `http://localhost:4000/admin`.

#### Docker Services

```bash
# Core services
make up                 # Start PostgreSQL
make down              # Stop all services

# With management tools
make up-tools          # Add pgAdmin

# Useful commands
make logs              # View all service logs
make psql             # Connect to PostgreSQL
make health           # Check service health
```

#### Management Tools (Optional)

Start with management tools for easy database administration:

```bash
make tools
```

- **pgAdmin**: http://localhost:8080 (admin@clio.local / admin)

#### PostgreSQL 18+ Authentication

This setup uses PostgreSQL 18 with the new SCRAM-SHA-256 authentication method (default since PostgreSQL 18). The Docker configuration automatically handles this with:

```yaml
POSTGRES_INITDB_ARGS: "--auth-host=scram-sha-256 --auth-local=scram-sha-256"
```

If you need to use older PostgreSQL versions (14-17), they default to md5 authentication and don't require special configuration.

### Native Setup

If you prefer to install dependencies locally:

```bash
# Clone and enter the umbrella
cd clio_umbrella

# Install dependencies
mix deps.get

# Create and migrate database
mix ecto.setup

# Start the server
mix phx.server
```

The API will be available at `http://localhost:4000/api`.
The admin panel will be available at `http://localhost:4000/admin`.

### Configuration

#### Docker Configuration

When using Docker, configuration is handled automatically. You can customize settings by:

1. **Copy the example environment file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your preferences** (optional for development)

3. **The Docker setup uses convenient defaults** (see `.env.example` for PoC caveats)

#### Manual Configuration

For native installation, set these environment variables (or configure in `config/runtime.exs`):

```bash
# Database (adjust for your PostgreSQL setup)
export DATABASE_URL="ecto://postgres:postgres@localhost/redteamlogger"
# Security keys (generate secure ones for production)
export JWT_SECRET="your-jwt-secret-at-least-32-bytes-long"
export ADMIN_PASSWORD="AdminPassword123!"
export USER_PASSWORD="UserPassword123!"
export ADMIN_SECRET="your-admin-hmac-secret"
export CLOAK_KEY="base64-encoded-32-byte-aes-key"
export CACHE_ENCRYPTION_KEY="64-char-hex-string-for-cache-aes-256"
export FIELD_ENCRYPTION_KEY="64-char-hex-string-for-field-aes-256"
export SERVER_INSTANCE_ID="unique-server-id"

# Optional
export SECRET_KEY_BASE="phoenix-secret-key-base-64-bytes"
export PORT=4000
export DATA_DIR="data"  # where audit logs are stored
```

#### Generating Keys

The default dev keys in `.env.example` work out of the box. To rotate them (recommended for any shared environment):

```bash
# JWT Secret (32+ bytes)
openssl rand -base64 32

# Phoenix Secret Key Base (64+ bytes)
openssl rand -base64 64

# AES-256 Keys (32 bytes = 64 hex characters)
openssl rand -hex 32

# Base64 AES Key for Cloak
openssl rand -base64 32
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

## Admin Panel (Backpex)

CLIO includes a browser-based admin panel built with [Backpex](https://hexdocs.pm/backpex) for managing all resources through a visual CRUD interface.

### Accessing the Admin Panel

Navigate to `http://localhost:4000/admin` in your browser. You will be redirected to a login page. Sign in with admin credentials (the same username/password used for the API).

Only users with the `admin` role can access the panel. Non-admin users will see an "Admin access required" error.

### Setup Requirements

The admin panel requires frontend assets that are not needed by the JSON API. After installing dependencies, run:

```bash
# Install daisyUI (CSS framework used by Backpex)
cd apps/clio_web/assets && npm install && cd -

# Install Tailwind and esbuild standalone CLIs
mix assets.setup

# Build assets
mix assets.build
```

In development, `mix phx.server` will automatically watch and rebuild assets via the configured esbuild/tailwind watchers.

### Available Resources

The admin panel provides full CRUD (create, read, update, delete) for all 13 data models:

| Resource | Path | Description |
|----------|------|-------------|
| Logs | `/admin/logs` | Red team log entries with forensic fields |
| Tags | `/admin/tags` | Categorized tags (technique, tool, target, etc.) |
| Log Tags | `/admin/log-tags` | Log-to-tag assignments |
| Operations | `/admin/operations` | Red team campaigns |
| User Operations | `/admin/user-operations` | User-to-operation assignments |
| Evidence Files | `/admin/evidence-files` | Evidence file metadata |
| Log Templates | `/admin/log-templates` | Reusable log entry templates |
| API Keys | `/admin/api-keys` | API key management |
| Relations | `/admin/relations` | Discovered patterns and relationships |
| File Statuses | `/admin/file-statuses` | DFIR file status tracking |
| File Status History | `/admin/file-status-history` | File status change history |
| Tag Relationships | `/admin/tag-relationships` | Tag co-occurrence and sequences |
| Log Relationships | `/admin/log-relationships` | Relationships between log entries |

### Architecture

The admin panel runs alongside the existing JSON API without interfering:

- **Auth**: Uses session-based authentication (separate from JWT API auth) via `CloWeb.Plugs.AdminSession` and a `CloWeb.Live.AdminAuth` LiveView on_mount hook. Login delegates to the same `Clio.Auth.authenticate/2` used by the API.
- **Routes**: All admin routes live under `/admin`, using a `:browser` pipeline. The existing `/api` routes are unchanged.
- **Layout**: Uses `Backpex.HTML.Layout.app_shell` with a sidebar for navigation between resources.
- **LiveResources**: Each resource is a `Backpex.LiveResource` module in `lib/clo_web/live/admin/` that defines which fields to display, their types, and labels.

### Key Dependencies Added

| Package | Version | Purpose |
|---------|---------|---------|
| `backpex` | `~> 0.17` | Admin panel framework |
| `phoenix_live_view` | `~> 1.0` | Upgraded from `~> 0.19` for Backpex compatibility |
| `phoenix_html` | `~> 4.1` | Upgraded from `~> 3.3` for Backpex compatibility |
| `daisyui` | `^5.0.0` | CSS component library (npm, in `assets/`) |
| `tailwind` | `~> 0.2` | Tailwind CSS v4 standalone CLI |
| `esbuild` | `~> 0.8` | JavaScript bundler |
| `gettext` | `~> 0.26` | Internationalization (required by Backpex) |

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

### With Docker

```bash
# Start test database and run tests
make test

# Run tests in watch mode
make test-watch

# Run specific app tests
cd apps/clio && mix test
cd apps/clio_web && mix test
```

### Native Testing

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

### Docker Development

```bash
# First-time setup (start postgres + install deps + migrate + seed)
make dev

# Day-to-day workflow
make up                    # Start PostgreSQL
mix deps.get              # Install dependencies
mix ecto.migrate          # Run migrations
iex -S mix phx.server     # Start with IEx shell

# Database operations
make migrate              # Run migrations
make seed                 # Run seeds
make reset                # Reset database (drop, create, migrate, seed)
make psql                 # Connect to database
```

### Native Development

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

### Database Backup & Restore

```bash
# Backup database
make backup-db

# Restore from backup
make restore-db BACKUP_FILE=backup_20240101_120000.sql
```

## License

Proprietary - Internal use only.
