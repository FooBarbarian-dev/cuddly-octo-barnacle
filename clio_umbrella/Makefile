# CLIO Development Makefile
# Convenient commands for Docker-based development

.PHONY: help setup up down logs clean test migrate seed reset psql tools health dev

# Default target
help: ## Show this help message
	@echo "CLIO Development Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Profiles:"
	@echo "  Default: postgres (core services only)"
	@echo "  tools:   Includes pgAdmin"
	@echo "  test:    Includes test database"

# Initial setup - starts infrastructure only
setup: ## Create data directories and start PostgreSQL (run mix deps.get && mix ecto.setup next)
	mkdir -p data/postgres data/app
	docker compose up -d postgres
	@echo "Waiting for PostgreSQL to be ready..."
	@until docker compose exec -T postgres pg_isready -U postgres -d redteamlogger >/dev/null 2>&1; do printf '.'; sleep 1; done
	@echo ""
	@echo "PostgreSQL is ready!"
	@echo ""
	@echo "Complete setup by running:"
	@echo "  mix deps.get && mix ecto.setup"

# Full first-time development setup
dev: ## First-time setup: start services, install deps, migrate, and seed
	mkdir -p data/postgres data/app
	@if [ ! -f .env ] && [ -f .env.example ]; then cp .env.example .env; echo "Created .env from template"; fi
	docker compose up -d postgres
	@echo "Waiting for PostgreSQL to be ready..."
	@until docker compose exec -T postgres pg_isready -U postgres -d redteamlogger >/dev/null 2>&1; do printf '.'; sleep 1; done
	@echo ""
	mix deps.get
	mix ecto.setup
	@echo ""
	@echo "Setup complete! Start the application:"
	@echo "  mix phx.server"
	@echo "  iex -S mix phx.server   # with interactive shell"

# Service management
up: ## Start core services (postgres)
	docker compose up -d postgres

up-tools: ## Start services with management tools (pgAdmin)
	docker compose --profile tools up -d

down: ## Stop all services
	docker compose --profile tools --profile test down

restart: down up ## Restart core services

# Logs
logs: ## Show logs from all services
	docker compose logs -f

logs-postgres: ## Show PostgreSQL logs
	docker compose logs -f postgres

# Database operations
migrate: ## Run database migrations
	mix ecto.migrate

seed: ## Run database seeds
	mix run apps/clio/priv/repo/seeds.exs

reset: ## Reset database (drop, create, migrate, seed)
	mix ecto.reset

psql: ## Connect to PostgreSQL database
	docker compose exec postgres psql -U postgres -d redteamlogger

psql-test: ## Connect to test PostgreSQL database
	docker compose exec postgres_test psql -U postgres -d redteamlogger_test

# Testing
test-setup: ## Start test database
	docker compose --profile test up -d postgres_test
	@echo "Waiting for test database..."
	@until docker compose exec -T postgres_test pg_isready -U postgres -d redteamlogger_test >/dev/null 2>&1; do printf '.'; sleep 1; done
	@echo ""

test: test-setup ## Run tests
	MIX_ENV=test mix test

test-watch: test-setup ## Run tests in watch mode
	MIX_ENV=test mix test.watch

# Cleanup
clean: ## Remove all containers, volumes, and data (WARNING: destroys all data)
	docker compose --profile tools --profile test down -v
	docker system prune -f
	sudo rm -rf data/

# Health checks
health: ## Check service health
	@echo "Checking PostgreSQL..."
	@docker compose exec postgres pg_isready -U postgres -d redteamlogger && echo "PostgreSQL is ready" || echo "PostgreSQL is not ready"

# Management tools
tools: up-tools ## Start management tools (pgAdmin)
	@echo "Management tools started!"
	@echo ""
	@echo "Tools:"
	@echo "  pgAdmin: http://localhost:8080 (admin@clio.local / admin)"

# Backup and restore
backup-db: ## Backup database
	docker compose exec postgres pg_dump -U postgres redteamlogger > backup_$(shell date +%Y%m%d_%H%M%S).sql

restore-db: ## Restore database from backup (specify BACKUP_FILE)
	@if [ -z "$(BACKUP_FILE)" ]; then echo "Please specify BACKUP_FILE=<filename>"; exit 1; fi
	docker compose exec -T postgres psql -U postgres redteamlogger < $(BACKUP_FILE)
