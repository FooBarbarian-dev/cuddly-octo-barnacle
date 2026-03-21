defmodule Clio.Repo do
  use Ecto.Repo,
    otp_app: :clio,
    adapter: Ecto.Adapters.Postgres
end
