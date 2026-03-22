defmodule Clio.Repo do
  @moduledoc "Ecto repository for PostgreSQL database access."
  use Ecto.Repo,
    otp_app: :clio,
    adapter: Ecto.Adapters.Postgres
end
