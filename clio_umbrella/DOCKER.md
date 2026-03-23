# Docker Quick Reference for CLIO

Docker is used to run PostgreSQL. The application itself runs natively via `mix` for hot code reloading and easy development.

## Quick Start

```bash
# Automated first-time setup (recommended)
make dev
mix phx.server

# Or step-by-step:
make up           # Start PostgreSQL (waits until ready)
mix deps.get      # Install Elixir dependencies
mix ecto.setup    # Create DB, run migrations, load seeds
mix phx.server    # Start the application

# Or use the setup script (does the same as above):
./setup.sh
mix phx.server
```

## Docker Services

| Service | Image | Port | Profile | Purpose |
|---------|-------|------|---------|---------|
| `postgres` | postgres:18-alpine | 5432 | default | PostgreSQL 18 database |
| `pgadmin` | dpage/pgadmin4 | 8080 | tools | PostgreSQL web admin |
| `postgres_test` | postgres:18-alpine | 5433 | test | Isolated test database |

## Service Profiles

```bash
# Default profile (postgres only)
docker compose up -d

# Tools profile (adds pgAdmin)
docker compose --profile tools up -d

# Test profile (adds test database)
docker compose --profile test up -d
```

## Makefile Commands

### Service Management

```bash
make up           # Start PostgreSQL
make up-tools     # Start with pgAdmin
make down         # Stop all services
make restart      # Restart core services
```

### First-Time Setup

```bash
make dev          # Full setup: start postgres, install deps, migrate, seed
make setup        # Infrastructure only: start postgres and wait until ready
```

### Database Operations

```bash
make migrate      # Run database migrations
make seed         # Run database seeds
make reset        # Reset database (drop, create, migrate, seed)
make psql         # Connect to PostgreSQL shell
make psql-test    # Connect to test database shell
make backup-db    # Backup database to SQL file
make restore-db BACKUP_FILE=backup.sql  # Restore from backup
```

### Logs and Monitoring

```bash
make logs          # Show all service logs
make logs-postgres # Show PostgreSQL logs only
make health        # Check service health
```

### Testing

```bash
make test          # Start test DB and run all tests
make test-setup    # Start test database only
make test-watch    # Run tests in watch mode
```

### Cleanup

```bash
make clean         # Remove all containers, volumes, and local data (destructive)
```

## Direct Docker Commands

### Service Control

```bash
# Start services
docker compose up -d postgres

# Stop services
docker compose down

# View logs
docker compose logs -f postgres

# Check status
docker compose ps
```

### Database Access

```bash
# PostgreSQL shell
docker compose exec postgres psql -U postgres -d redteamlogger

# Check PostgreSQL is ready
docker compose exec postgres pg_isready -U postgres -d redteamlogger
```

## PostgreSQL 18 Authentication

PostgreSQL 18+ uses SCRAM-SHA-256 authentication by default. The Docker setup handles this automatically:

```yaml
environment:
  POSTGRES_INITDB_ARGS: "--auth-host=scram-sha-256 --auth-local=scram-sha-256"
```

Elixir's `postgrex` driver supports SCRAM-SHA-256 out of the box — no extra configuration required.

### Troubleshooting Authentication

```bash
# Check authentication method in use
docker compose exec postgres cat /var/lib/postgresql/data/pg_hba.conf

# Check PostgreSQL version
docker compose exec postgres psql -U postgres -c "SELECT version();"
```

## Environment Configuration

### Default Development Configuration

```yaml
# Database
POSTGRES_USER: postgres
POSTGRES_PASSWORD: postgres
POSTGRES_DB: redteamlogger

# Application (set in .env)
ADMIN_PASSWORD: AdminPassword123!
USER_PASSWORD: UserPassword123!
JWT_SECRET: (from .env)
```

### Custom Configuration

1. Copy environment template:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your settings

3. Restart services:
   ```bash
   make restart
   ```

## Data Persistence

### Docker Volume Mounts

```yaml
volumes:
  - postgres_data:/var/lib/postgresql/data    # PostgreSQL data (persists between restarts)
  - pgadmin_data:/var/lib/pgadmin            # pgAdmin settings
```

### Local Data Directories

```
data/
├── postgres/     # (reserved for local postgres data if needed)
└── app/          # Application data (audit logs, uploads)
```

### Backup Strategy

```bash
# Database backup (creates timestamped .sql file)
make backup-db

# Manual backup
docker compose exec postgres pg_dump -U postgres redteamlogger > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore from backup
make restore-db BACKUP_FILE=backup_20240101_120000.sql
```

## Troubleshooting

### Services Won't Start

```bash
# Check Docker daemon
docker info

# Check port conflicts
netstat -tlnp | grep -E ':(4000|5432|5433|8080)'

# Check logs for errors
make logs
```

### Database Connection Issues

```bash
# Check PostgreSQL is ready
make health

# Connect directly
make psql

# Reset the database
make reset
```

### Fresh Start

```bash
# Complete cleanup (WARNING: destroys all data)
make clean

# Fresh setup
make dev
mix phx.server
```

## Security Notes

### Development vs Production

**Development (Docker Compose):**
- Uses default passwords (change immediately after first login)
- No SSL/TLS encryption
- Exposes all ports to localhost

**Production:**
- Generate secure random passwords and keys (see `.env.example` for commands)
- Enable SSL/TLS for database connections
- Use proper firewall rules and a secrets management system

### Key Generation for Production

```bash
openssl rand -base64 32   # JWT_SECRET, ADMIN_SECRET, CLOAK_KEY
openssl rand -base64 64   # SECRET_KEY_BASE
openssl rand -hex 32      # FIELD_ENCRYPTION_KEY, CACHE_ENCRYPTION_KEY
```

## CI/CD Integration

### GitHub Actions

```yaml
services:
  postgres:
    image: postgres:18
    env:
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: redteamlogger_test
    options: >-
      --health-cmd pg_isready
      --health-interval 10s
      --health-timeout 5s
      --health-retries 5
```

### GitLab CI

```yaml
services:
  - name: postgres:18
    alias: postgres

variables:
  POSTGRES_DB: redteamlogger_test
  POSTGRES_PASSWORD: postgres
```
