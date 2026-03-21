defmodule ClioRelations.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Clio.Relations.Coordinator, []},
      {Clio.Relations.Cache, []}
    ]

    opts = [strategy: :one_for_one, name: ClioRelations.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
