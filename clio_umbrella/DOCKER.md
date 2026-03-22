# Docker Quick Reference for CLIO

This document provides a quick reference for working with CLIO's Docker setup.

## Quick Start

```bash
# One-command setup (recommended for new users)
./setup.sh

# Or step-by-step:
make setup      # Create directories and start services
mix deps.get    # Install Elixir dependencies
mix ecto.migrate # Run database migrations
mix phx.server  # Start the application
```

## Docker Services

### Core Services (Always needed)

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| `postgres` | postgres:18-alpine | 5432 | PostgreSQL 18 database with SCRAM-SHA-256 auth |

### Optional Services

| Service | Image | Port | Purpose |
|---------|-------|------|---------|
| `app` | clio:dev | 4000 | Application container (dev profile) |
| `pgadmin` | dpage/pgadmin4 | 8080 | PostgreSQL web admin (tools profile) |
| `postgres_test` | postgres:18-alpine | 5433 | Test database (test profile) |

## Service Profiles

Docker Compose uses profiles to group services:

```bash
# Default profile (core services only)
docker-compose up -d

# Development profile (includes app container)
docker-compose --profile dev up -d

# Tools profile (includes pgAdmin)
docker-compose --profile tools up -d

# Test profile (includes test database)
docker-compose --profile test up -d

# Multiple profiles
docker-compose --profile dev --profile tools up -d
```

## Makefile Commands

### Service Management

```bash
make up           # Start core services (postgres)
make up-dev       # Start with application container
make up-tools     # Start with management tools
make up-all       # Start everything (dev + tools)
make down         # Stop all services
make restart      # Restart core services
```

### Development Workflow

```bash
make dev          # Quick development setup
make setup        # Create directories and start services
make build        # Build application Docker image
make clean        # Remove containers, volumes, and data
```

### Database Operations

```bash
make migrate      # Run database migrations
make seed         # Run database seeds
make reset        # Reset database (drop, create, migrate, seed)
make psql         # Connect to PostgreSQL
make psql-test    # Connect to test database
make backup-db    # Backup database
make restore-db BACKUP_FILE=backup.sql  # Restore database
```

### Logs and Monitoring

```bash
make logs         # Show all service logs
make logs-app     # Show application logs only
make logs-postgres # Show PostgreSQL logs only
make health       # Check service health
```

### Application Development

```bash
make shell        # Open shell in application container
make iex          # Open IEx shell in application container
```

### Testing

```bash
make test         # Start test DB and run tests
make test-setup   # Start test database only
make test-watch   # Run tests in watch mode
```

## Direct Docker Commands

### Service Control

```bash
# Start services
docker-compose up -d postgres

# Stop services
docker-compose down

# View logs
docker-compose logs -f postgres

# Check status
docker-compose ps
```

### Database Access

```bash
# PostgreSQL shell
docker-compose exec postgres psql -U postgres -d redteamlogger

# Check PostgreSQL is ready
docker-compose exec postgres pg_isready -U postgres -d redteamlogger
```

### Application Container

```bash
# Build application image
docker-compose build app

# Run application container
docker-compose --profile dev up -d app

# Execute commands in app container
docker-compose exec app mix ecto.migrate
docker-compose exec app iex -S mix

# Open shell in app container
docker-compose exec app sh
```

## PostgreSQL 18 Changes

PostgreSQL 18+ uses SCRAM-SHA-256 authentication by default. Our Docker setup handles this automatically with:

```yaml
environment:
  POSTGRES_INITDB_ARGS: "--auth-host=scram-sha-256 --auth-local=scram-sha-256"
```

### Key Differences from Older Versions:

- **Authentication Method**: SCRAM-SHA-256 instead of MD5
- **Password Storage**: More secure password hashing
- **Client Compatibility**: Requires compatible client drivers (Elixir's Postgrex supports this)

### Troubleshooting Authentication

If you encounter authentication issues:

```bash
# Check authentication methods
docker-compose exec postgres cat /var/lib/postgresql/data/pg_hba.conf

# Check PostgreSQL version
docker-compose exec postgres psql -U postgres -c "SELECT version();"

# Check user authentication method
docker-compose exec postgres psql -U postgres -c "\du+"
```

## Environment Configuration

### Default Development Configuration

The Docker setup uses these defaults:

```yaml
# Database
POSTGRES_USER: postgres
POSTGRES_PASSWORD: postgres
POSTGRES_DB: redteamlogger

# Application
ADMIN_PASSWORD: AdminPassword123!
USER_PASSWORD: UserPassword123!
JWT_SECRET: dev_jwt_secret_at_least_32_bytes_long_for_development_only
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

### Volume Mounts

```yaml
volumes:
  - postgres_data:/var/lib/postgresql/data    # PostgreSQL data
  - pgadmin_data:/var/lib/pgadmin            # pgAdmin settings
  - ./data/app:/app/data                     # Application data (audit logs)
```

### Local Data Directories

```
data/
├── postgres/     # PostgreSQL data files
└── app/          # Application data (audit logs, uploads)
```

### Backup Strategy

```bash
# Database backup
make backup-db

# Manual backup with timestamp
docker-compose exec postgres pg_dump -U postgres redteamlogger > backup_$(date +%Y%m%d_%H%M%S).sql

# Backup with Docker volume
docker run --rm -v clio_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres_backup.tar.gz -C /data .
```

## Troubleshooting

### Common Issues

**Services won't start:**
```bash
# Check Docker daemon
docker info

# Check port conflicts
netstat -tlnp | grep -E ':(4000|5432|8080)'

# Check logs for errors
make logs
```

**Database connection issues:**
```bash
# Check PostgreSQL is ready
make health

# Check authentication
docker-compose exec postgres psql -U postgres -d redteamlogger

# Reset database
make reset
```

**Application won't connect:**
```bash
# Check environment variables
docker-compose exec app env | grep DATABASE

# Check services are accessible
docker-compose exec app ping postgres
```

### Reset Everything

```bash
# Complete cleanup (WARNING: destroys all data)
make clean

# Fresh setup
make setup
```

### Performance Tuning

**PostgreSQL:**
```bash
# Connect and check settings
make psql
# In psql:
SHOW shared_buffers;
SHOW max_connections;
SHOW work_mem;
```

## Security Notes

### Development vs Production

**Development (Docker Compose):**
- Uses default passwords
- No SSL/TLS encryption
- Exposes all ports to localhost
- Uses development encryption keys

**Production:**
- Generate secure random passwords
- Enable SSL/TLS for database connections
- Use proper firewall rules
- Generate production encryption keys
- Use secrets management system

### Key Generation for Production

```bash
# Generate secure keys
openssl rand -base64 32  # JWT_SECRET
openssl rand -base64 64  # SECRET_KEY_BASE
openssl rand -hex 32     # FIELD_ENCRYPTION_KEY
openssl rand -hex 32     # CACHE_ENCRYPTION_KEY
openssl rand -base64 32  # CLOAK_KEY
```

## Integration with CI/CD

### GitHub Actions Example

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

### GitLab CI Example

```yaml
services:
  - name: postgres:18
    alias: postgres

variables:
  POSTGRES_DB: redteamlogger_test
  POSTGRES_PASSWORD: postgres
```
