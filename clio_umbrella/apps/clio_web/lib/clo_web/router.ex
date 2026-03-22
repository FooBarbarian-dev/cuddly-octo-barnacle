defmodule CloWeb.Router do
  @moduledoc "API router with public, authenticated, and admin-only route scopes."
  use CloWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated do
    plug CloWeb.Plugs.Auth
  end

  pipeline :admin_only do
    plug CloWeb.Plugs.Admin
  end

  pipeline :rate_limited do
    plug CloWeb.Plugs.RateLimit, limit: 100, period: 60_000
  end

  pipeline :auth_rate_limited do
    plug CloWeb.Plugs.RateLimit, limit: 10, period: 60_000
  end

  # ── Public routes ──
  scope "/api", CloWeb do
    pipe_through [:api, :auth_rate_limited]

    post "/auth/login", AuthController, :login
  end

  # ── Authenticated routes ──
  scope "/api", CloWeb do
    pipe_through [:api, :rate_limited, :authenticated]

    # Auth
    get "/auth/verify", AuthController, :verify
    post "/auth/logout", AuthController, :logout
    put "/auth/password", AuthController, :change_password

    # Logs
    resources "/logs", LogController, except: [:new, :edit]
    post "/logs/bulk-delete", LogController, :bulk_delete
    post "/logs/:id/lock", LogController, :lock
    post "/logs/:id/unlock", LogController, :unlock

    # Tags — static routes must come before :id routes
    get "/tags/search/autocomplete", TagController, :autocomplete
    get "/tags/stats/usage", TagController, :stats
    resources "/tags", TagController, except: [:new, :edit]
    post "/logs/:log_id/tags/:tag_id", TagController, :add_to_log
    delete "/logs/:log_id/tags/:tag_id", TagController, :remove_from_log

    # Operations — static routes must come before :id routes
    get "/operations/mine/list", OperationController, :my_operations
    resources "/operations", OperationController, except: [:new, :edit]
    post "/operations/:id/assign", OperationController, :assign_user
    delete "/operations/:id/assign/:username", OperationController, :unassign_user
    post "/operations/:id/activate", OperationController, :set_active

    # Templates
    resources "/templates", TemplateController, except: [:new, :edit]

    # Evidence
    get "/logs/:log_id/evidence", EvidenceController, :index
    post "/logs/:log_id/evidence", EvidenceController, :upload
    get "/evidence/:id/download", EvidenceController, :download
    delete "/evidence/:id", EvidenceController, :delete

    # Export
    get "/export/csv", ExportController, :export_csv
    get "/export/json", ExportController, :export_json
  end

  # ── Admin routes ──
  scope "/api/admin", CloWeb do
    pipe_through [:api, :rate_limited, :authenticated, :admin_only]

    # API Keys
    resources "/api-keys", ApiKeyController, only: [:index, :create]
    post "/api-keys/:id/revoke", ApiKeyController, :revoke

    # Audit logs
    get "/audit/:category", ExportController, :audit_logs
  end

  # Health check
  scope "/api", CloWeb do
    pipe_through :api

    get "/health", HealthController, :check
  end
end
