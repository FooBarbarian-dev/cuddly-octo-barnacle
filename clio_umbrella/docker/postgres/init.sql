-- PostgreSQL initialization script for CLIO
-- This script runs automatically when the PostgreSQL container starts for the first time

-- Ensure the database exists (it should already be created by POSTGRES_DB)
SELECT 'CREATE DATABASE redteamlogger'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'redteamlogger')\gexec

-- Connect to the redteamlogger database
\c redteamlogger;

-- Create extensions that might be useful for the application
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Set up proper permissions
GRANT ALL PRIVILEGES ON DATABASE redteamlogger TO postgres;

-- Log successful initialization
SELECT 'CLIO database initialized successfully' AS status;
