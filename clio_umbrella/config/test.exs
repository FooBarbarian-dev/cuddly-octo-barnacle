import Config

config :clio, Clio.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "redteamlogger_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :clio_web, CloWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_that_is_at_least_64_bytes_long_for_testing_only_aaaa",
  server: false

config :clio,
  jwt_secret: "test_jwt_secret_that_is_at_least_32_bytes_long",
  admin_password: "test_admin_password",
  user_password: "test_user_password",
  admin_secret: "test_admin_secret_key_for_hmac",
  server_instance_id: "test_instance_001",
  data_dir: "test/tmp/data",
  cache_encryption_key: "0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF"

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :pbkdf2_elixir, rounds: 1
