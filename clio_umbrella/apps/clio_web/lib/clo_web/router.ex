defmodule CloWeb.Router do
  @moduledoc "API router with public, authenticated, and admin-only route scopes, plus Backpex admin panel."
  use CloWeb, :router
  import Backpex.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CloWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :authenticated do
    plug CloWeb.Plugs.Auth
  end

  pipeline :admin_only do
    plug CloWeb.Plugs.Admin
  end

  pipeline :admin_session do
    plug CloWeb.Plugs.AdminSession
  end

  pipeline :rate_limited do
    plug CloWeb.Plugs.RateLimit, limit: 100, period: 60_000
  end

  pipeline :auth_rate_limited do
    plug CloWeb.Plugs.RateLimit, limit: 10, period: 60_000
  end

  # ── Clio LiveView UI ──

  # Public: login page
  scope "/", CloWeb do
    pipe_through :browser

    live "/login", LoginLive, :index
    get "/auth/callback", AuthCallbackController, :callback
  end

  # Authenticated LiveView routes
  scope "/", CloWeb do
    pipe_through :browser

    live_session :authenticated,
      on_mount: [{CloWeb.Hooks.RequireAuth, :default}] do
      live "/", LogsLive, :index
      live "/relations", RelationsLive, :index
      live "/file-status", FileStatusLive, :index
      live "/settings", SettingsLive, :index
    end

    live_session :clio_admin,
      on_mount: [{CloWeb.Hooks.RequireAuth, :default}, {CloWeb.Hooks.RequireAdmin, :default}] do
      live "/manage/operations", Admin.OperationsLive, :index
      live "/manage/tags", Admin.TagsLive, :index
      live "/manage/export", Admin.ExportLive, :index
      live "/manage/sessions", Admin.SessionsLive, :index
      live "/manage/api-keys", Admin.ApiKeysLive, :index
      live "/manage/api-docs", Admin.ApiDocsLive, :index
      live "/manage/log-management", Admin.LogManagementLive, :index
    end
  end

  # ── Admin panel (Backpex) ──
  scope "/admin", CloWeb do
    pipe_through :browser

    # Public admin login
    get "/session/login", AdminSessionController, :login
    post "/session/login", AdminSessionController, :create
    delete "/session/logout", AdminSessionController, :logout
  end

  scope "/admin", CloWeb do
    pipe_through [:browser, :admin_session]
    backpex_routes()

    live_session :admin,
      on_mount: [
        {CloWeb.Live.AdminAuth, :default},
        {Backpex.InitAssigns, :default}
      ],
      layout: {CloWeb.Layouts, :admin} do
      live_resources "/logs", Live.Admin.LogLive
      live_resources "/tags", Live.Admin.TagLive
      live_resources "/log-tags", Live.Admin.LogTagLive
      live_resources "/operations", Live.Admin.OperationLive
      live_resources "/user-operations", Live.Admin.UserOperationLive
      live_resources "/evidence-files", Live.Admin.EvidenceFileLive
      live_resources "/log-templates", Live.Admin.LogTemplateLive
      live_resources "/api-keys", Live.Admin.ApiKeyLive
      live_resources "/relations", Live.Admin.RelationLive
      live_resources "/file-statuses", Live.Admin.FileStatusLive
      live_resources "/file-status-history", Live.Admin.FileStatusHistoryLive
      live_resources "/tag-relationships", Live.Admin.TagRelationshipLive
      live_resources "/log-relationships", Live.Admin.LogRelationshipLive
    end
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
