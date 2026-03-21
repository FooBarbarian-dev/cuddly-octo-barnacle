import Config

config :clio, Clio.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "redteamlogger",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :clio_web, CloWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_secret_key_base_that_is_at_least_64_bytes_long_for_development_only_aaaa",
  watchers: []

config :clio_web, CloWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|svg)$",
      ~r"lib/clo_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime
