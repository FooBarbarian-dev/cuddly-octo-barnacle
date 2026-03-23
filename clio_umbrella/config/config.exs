import Config

config :clio,
  ecto_repos: [Clio.Repo]

config :clio, Clio.Repo,
  migration_primary_key: [type: :serial],
  migration_timestamps: [type: :utc_datetime_usec]

config :clio, Clio.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      tag: "AES.GCM.V1",
      key: Base.decode64!("dGVzdGtleXRlc3RrZXl0ZXN0a2V5dGVzdGtleXRlcw=="),
      iv_length: 12
    }
  ]

config :clio_web,
  generators: [context_app: :clio]

config :clio_web, CloWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: CloWeb.ErrorHTML, json: CloWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: CloWeb.PubSub,
  live_view: [signing_salt: "clio_live_view_salt"]

config :backpex, :pubsub_server, CloWeb.PubSub

config :esbuild,
  version: "0.24.2",
  clio_web: [
    args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/clio_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "4.0.0",
  clio_web: [
    args: ~w(
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/clio_web/assets", __DIR__)
  ]

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
