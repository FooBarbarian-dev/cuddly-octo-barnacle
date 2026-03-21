defmodule Clio.Logs.LockReaper do
  @moduledoc "GenServer that periodically unlocks stale row locks (30-minute TTL)."
  use GenServer

  import Ecto.Query
  alias Clio.Repo
  alias Clio.Logs.Log

  @check_interval :timer.minutes(5)
  @lock_ttl_minutes 30

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_check()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:check_locks, state) do
    reap_stale_locks()
    schedule_check()
    {:noreply, state}
  end

  defp reap_stale_locks do
    cutoff = DateTime.add(DateTime.utc_now(), -@lock_ttl_minutes, :minute)

    from(l in Log,
      where: l.locked == true and l.updated_at < ^cutoff
    )
    |> Repo.update_all(set: [locked: false, locked_by: nil])
  end

  defp schedule_check do
    Process.send_after(self(), :check_locks, @check_interval)
  end
end
