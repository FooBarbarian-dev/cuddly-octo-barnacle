defmodule Clio.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Clio.Repo,
      Clio.Vault,
      {Clio.Redis.Pool, []},
      {Clio.Audit.Writer, []},
      {Clio.Export.RotationScheduler, []},
      {Clio.Logs.LockReaper, []}
    ]

    opts = [strategy: :one_for_one, name: Clio.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
