#!/bin/bash

# CLIO Development Environment Setup Script
# This script sets up the CLIO development environment with Docker

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    if ! command_exists docker; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    if ! command_exists docker-compose; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi

    if ! command_exists mix; then
        print_error "Elixir/Mix is not installed. Please install Elixir first."
        exit 1
    fi

    print_success "All prerequisites are installed"
}

# Create necessary directories
setup_directories() {
    print_status "Setting up directories..."

    mkdir -p data/postgres
    mkdir -p data/app

    print_success "Directories created"
}

# Setup environment file
setup_environment() {
    print_status "Setting up environment configuration..."

    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
            print_success "Environment file created from template"
        else
            print_warning "No .env.example found, skipping environment setup"
        fi
    else
        print_warning ".env already exists, skipping"
    fi
}

# Start Docker services
start_services() {
    print_status "Starting Docker services..."

    # Stop any existing services
    docker-compose down >/dev/null 2>&1 || true

    # Start PostgreSQL
    docker-compose up -d postgres

    print_status "Waiting for services to be ready..."

    # Wait for PostgreSQL to be ready
    for i in {1..30}; do
        if docker-compose exec -T postgres pg_isready -U postgres -d redteamlogger >/dev/null 2>&1; then
            break
        fi
        sleep 2
        if [ $i -eq 30 ]; then
            print_error "PostgreSQL failed to start within 60 seconds"
            exit 1
        fi
    done

    print_success "Services are ready"
}

# Setup Elixir application
setup_application() {
    print_status "Setting up Elixir application..."

    # Install dependencies
    print_status "Installing dependencies..."
    mix deps.get

    # Create and migrate database
    print_status "Setting up database..."
    mix ecto.create
    mix ecto.migrate

    # Run seeds
    print_status "Running database seeds..."
    mix run apps/clio/priv/repo/seeds.exs

    print_success "Application setup complete"
}

# Display final information
display_info() {
    echo
    echo -e "${GREEN}🚀 CLIO Development Environment Setup Complete!${NC}"
    echo
    echo -e "${BLUE}Services:${NC}"
    echo "  - PostgreSQL: localhost:5432"
    echo "  - Application: Will be available at http://localhost:4000"
    echo
    echo -e "${BLUE}Default Credentials:${NC}"
    echo "  - Admin: admin / AdminPassword123!"
    echo "  - User: user / UserPassword123!"
    echo "  ⚠️  Change these passwords after first login!"
    echo
    echo -e "${BLUE}Next Steps:${NC}"
    echo "  1. Start the application:"
    echo "     mix phx.server"
    echo
    echo "  2. Or start with IEx shell:"
    echo "     iex -S mix phx.server"
    echo
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  - make up          # Start services"
    echo "  - make down        # Stop services"
    echo "  - make logs        # View logs"
    echo "  - make psql        # Connect to PostgreSQL"
    echo "  - make test        # Run tests"
    echo "  - make help        # Show all available commands"
    echo
    echo -e "${BLUE}Management Tools (optional):${NC}"
    echo "  - make tools       # Start pgAdmin"
    echo "  - pgAdmin: http://localhost:8080 (admin@clio.local / admin)"
    echo
}

# Main execution
main() {
    echo -e "${BLUE}CLIO Development Environment Setup${NC}"
    echo "======================================"
    echo

    check_prerequisites
    setup_directories
    setup_environment
    start_services
    setup_application
    display_info

    print_success "Setup completed successfully!"
}

# Handle script interruption
trap 'print_error "Setup interrupted!"; exit 1' INT TERM

# Check if we're in the right directory
if [ ! -f "mix.exs" ]; then
    print_error "This script must be run from the clio_umbrella directory"
    exit 1
fi

# Run main function
main
