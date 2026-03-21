defmodule Clio.Redis.Pool do
  @moduledoc "Manages a pool of Redix connections."

  def child_spec(_opts) do
    config = Application.get_env(:clio, Clio.Redis, [])
    host = Keyword.get(config, :host, "localhost")
    port = Keyword.get(config, :port, 6379)
    password = Keyword.get(config, :password)
    ssl = Keyword.get(config, :ssl, false)

    redix_opts = [host: host, port: port]
    redix_opts = if password, do: Keyword.put(redix_opts, :password, password), else: redix_opts
    redix_opts = if ssl, do: Keyword.put(redix_opts, :ssl, true), else: redix_opts

    children =
      for i <- 0..4 do
        Supervisor.child_spec({Redix, Keyword.put(redix_opts, :name, :"redix_#{i}")},
          id: {Redix, i}
        )
      end

    %{
      id: __MODULE__,
      type: :supervisor,
      start: {Supervisor, :start_link, [children, [strategy: :one_for_one, name: Clio.Redis.PoolSupervisor]]}
    }
  end

  def command(command) do
    Redix.command(:"redix_#{random_index()}", command)
  end

  def pipeline(commands) do
    Redix.pipeline(:"redix_#{random_index()}", commands)
  end

  defp random_index, do: Enum.random(0..4)
end
