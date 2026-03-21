import Config

if config_env() == :prod do
  # Database
  database_url =
    System.get_env("DATABASE_URL") ||
      "ecto://#{System.fetch_env!("POSTGRES_USER")}:#{System.fetch_env!("POSTGRES_PASSWORD")}@#{System.get_env("POSTGRES_HOST", "db")}:#{System.get_env("POSTGRES_PORT", "5432")}/#{System.get_env("POSTGRES_DB", "redteamlogger")}"

  config :clio, Clio.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10")),
    ssl: System.get_env("POSTGRES_SSL", "true") == "true",
    ssl_opts: [
      verify: :verify_none
    ]

  # Redis
  redis_password = System.fetch_env!("REDIS_PASSWORD")
  redis_ssl = System.get_env("REDIS_SSL", "true") == "true"
  redis_host = System.get_env("REDIS_HOST", "redis")
  redis_port = String.to_integer(System.get_env("REDIS_PORT", "6379"))

  config :clio, Clio.Redis,
    host: redis_host,
    port: redis_port,
    password: redis_password,
    ssl: redis_ssl,
    ssl_opts: [verify: :verify_none]

  # Encryption keys
  config :clio, :redis_encryption_key, System.fetch_env!("REDIS_ENCRYPTION_KEY")
  config :clio, :field_encryption_key, System.fetch_env!("FIELD_ENCRYPTION_KEY")
  config :clio, :jwt_secret, System.fetch_env!("JWT_SECRET")
  config :clio, :admin_secret, System.get_env("ADMIN_SECRET", "default_admin_secret")
  config :clio, :admin_password, System.fetch_env!("ADMIN_PASSWORD")
  config :clio, :user_password, System.fetch_env!("USER_PASSWORD")

  # Server instance ID (unique per boot)
  config :clio, :server_instance_id, Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)

  # Cloak vault
  field_key = System.fetch_env!("FIELD_ENCRYPTION_KEY") |> Base.decode16!(case: :mixed)

  config :clio, Clio.Vault,
    ciphers: [
      default: {
        Cloak.Ciphers.AES.GCM,
        tag: "AES.GCM.V1",
        key: field_key,
        iv_length: 12
      }
    ]

  # Phoenix endpoint
  host = System.get_env("HOSTNAME", "localhost")
  port = String.to_integer(System.get_env("PORT", "4000"))
  secret_key_base = System.fetch_env!("SECRET_KEY_BASE")

  config :clio_web, CloWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [ip: {0, 0, 0, 0}, port: port],
    secret_key_base: secret_key_base,
    server: true

  # Google OAuth (optional)
  google_client_id = System.get_env("GOOGLE_CLIENT_ID")

  if google_client_id do
    config :ueberauth, Ueberauth.Strategy.Google.OAuth,
      client_id: google_client_id,
      client_secret: System.fetch_env!("GOOGLE_CLIENT_SECRET")

    config :clio, :google_callback_url,
      System.get_env("GOOGLE_CALLBACK_URL", "https://localhost/api/auth/google/callback")
  end
else
  # Dev/test defaults
  config :clio, :redis_encryption_key,
    "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

  config :clio, :field_encryption_key,
    "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

  config :clio, :jwt_secret, "dev_jwt_secret_for_testing_only"
  config :clio, :admin_secret, "dev_admin_secret"
  config :clio, :admin_password, "AdminPassword123!"
  config :clio, :user_password, "UserPassword123!"
  config :clio, :server_instance_id, Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)

  config :clio, Clio.Redis,
    host: "localhost",
    port: 6379,
    password: nil,
    ssl: false

  config :clio, Clio.Vault,
    ciphers: [
      default: {
        Cloak.Ciphers.AES.GCM,
        tag: "AES.GCM.V1",
        key: Base.decode64!("dGVzdGtleXRlc3RrZXl0ZXN0a2V5dGVzdGtleXRlcw=="),
        iv_length: 12
      }
    ]
end
