# CLIO Development Makefile
# Convenient commands for Docker-based development

.PHONY: help setup up down logs build clean test migrate seed reset psql redis-cli

# Default target
help: ## Show this help message
	@echo "CLIO Development Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Profiles:"
	@echo "  Default: postgres, redis (core services only)"
	@echo "  dev:     Includes application container"
	@echo "  tools:   Includes pgAdmin and Redis Commander"
	@echo "  test:    Includes test database"

# Initial setup
setup: ## Create data directories and start services
	mkdir -p data/postgres data/redis data/app
	docker-compose up -d postgres redis
	@echo "Waiting for services to be ready..."
	sleep 10
	make migrate

# Service management
up: ## Start core services (postgres, redis)
	docker-compose up -d postgres redis

up-dev: ## Start all services including application
	docker-compose --profile dev up -d

up-tools: ## Start services with management tools
	docker-compose --profile tools up -d

up-all: ## Start everything (dev + tools)
	docker-compose --profile dev --profile tools up -d

down: ## Stop all services
	docker-compose --profile dev --profile tools --profile test down

restart: down up ## Restart core services

# Logs
logs: ## Show logs from all services
	docker-compose logs -f

logs-app: ## Show application logs
	docker-compose logs -f app

logs-postgres: ## Show PostgreSQL logs
	docker-compose logs -f postgres

logs-redis: ## Show Redis logs
	docker-compose logs -f redis

# Application management
build: ## Build application Docker image
	docker-compose build app

shell: ## Open shell in application container
	docker-compose exec app sh

iex: ## Open IEx shell in application container
	docker-compose exec app iex -S mix

# Database operations
migrate: ## Run database migrations
	mix ecto.migrate

seed: ## Run database seeds
	mix run apps/clio/priv/repo/seeds.exs

reset: ## Reset database (drop, create, migrate, seed)
	mix ecto.reset

psql: ## Connect to PostgreSQL database
	docker-compose exec postgres psql -U postgres -d redteamlogger

psql-test: ## Connect to test PostgreSQL database
	docker-compose exec postgres_test psql -U postgres -d redteamlogger_test

# Redis operations
redis-cli: ## Connect to Redis CLI
	docker-compose exec redis redis-cli

redis-flush: ## Flush all Redis data
	docker-compose exec redis redis-cli FLUSHALL

# Testing
test-setup: ## Start test database
	docker-compose --profile test up -d postgres_test
	@echo "Waiting for test database..."
	sleep 5

test: test-setup ## Run tests
	MIX_ENV=test mix test

test-watch: test-setup ## Run tests in watch mode
	MIX_ENV=test mix test.watch

# Cleanup
clean: ## Remove all containers, volumes, and data
	docker-compose --profile dev --profile tools --profile test down -v
	docker system prune -f
	sudo rm -rf data/

clean-build: ## Remove application build artifacts
	rm -rf _build deps
	docker-compose build --no-cache app

# Health checks
health: ## Check service health
	@echo "Checking PostgreSQL..."
	@docker-compose exec postgres pg_isready -U postgres -d redteamlogger && echo "✅ PostgreSQL is ready" || echo "❌ PostgreSQL is not ready"
	@echo "Checking Redis..."
	@docker-compose exec redis redis-cli ping && echo "✅ Redis is ready" || echo "❌ Redis is not ready"

# Development helpers
dev: setup up-dev ## Quick start for development (setup + start with app)
	@echo "🚀 CLIO development environment is ready!"
	@echo ""
	@echo "Services:"
	@echo "  - Application: http://localhost:4000"
	@echo "  - API: http://localhost:4000/api"
	@echo ""
	@echo "Useful commands:"
	@echo "  make logs-app    # View application logs"
	@echo "  make iex         # Open IEx shell"
	@echo "  make test        # Run tests"
	@echo ""

tools: up-tools ## Start management tools
	@echo "🛠️ Management tools started!"
	@echo ""
	@echo "Tools:"
	@echo "  - pgAdmin: http://localhost:8080 (admin@clio.local / admin)"
	@echo "  - Redis Commander: http://localhost:8081"

# Production-like setup
prod-setup: ## Setup for production-like testing
	@echo "⚠️  This creates a production-like environment with proper secrets"
	@echo "Make sure to set proper environment variables in .env.prod"
	docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Backup and restore
backup-db: ## Backup database
	docker-compose exec postgres pg_dump -U postgres redteamlogger > backup_$(shell date +%Y%m%d_%H%M%S).sql

restore-db: ## Restore database from backup (specify BACKUP_FILE)
	@if [ -z "$(BACKUP_FILE)" ]; then echo "Please specify BACKUP_FILE=<filename>"; exit 1; fi
	docker-compose exec -T postgres psql -U postgres redteamlogger < $(BACKUP_FILE)
