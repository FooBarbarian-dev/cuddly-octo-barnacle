defmodule Clio.Audit.Writer do
  @moduledoc "GenServer that serializes audit log writes to JSON files."
  use GenServer

  @max_entries 10_000
  @categories ~w(security data system audit)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def log_event(category, event) when category in @categories do
    GenServer.cast(__MODULE__, {:log_event, category, event})
  end

  @impl true
  def init(_opts) do
    data_dir = Application.get_env(:clio, :data_dir, "data")
    File.mkdir_p!(data_dir)

    # Initialize log files if they don't exist
    for cat <- @categories do
      path = Path.join(data_dir, "#{cat}_logs.json")
      unless File.exists?(path), do: File.write!(path, "[]")
    end

    {:ok, %{data_dir: data_dir, rotating: MapSet.new()}}
  end

  @impl true
  def handle_cast({:log_event, category, event}, state) do
    if MapSet.member?(state.rotating, category) do
      # Queue during rotation — just drop for now, a production impl would buffer
      {:noreply, state}
    else
      path = Path.join(state.data_dir, "#{category}_logs.json")
      enriched = enrich_event(event)

      case File.read(path) do
        {:ok, content} ->
          entries = Jason.decode!(content)

          if length(entries) >= @max_entries do
            # Trigger rotation
            {:noreply, state}
          else
            updated = entries ++ [enriched]
            File.write!(path, Jason.encode!(updated))
            {:noreply, state}
          end

        _ ->
          File.write!(path, Jason.encode!([enriched]))
          {:noreply, state}
      end
    end
  end

  @impl true
  def handle_call({:rotate, categories}, _from, state) do
    state = %{state | rotating: MapSet.new(categories)}
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:release_rotation, _from, state) do
    {:reply, :ok, %{state | rotating: MapSet.new()}}
  end

  defp enrich_event(event) do
    event
    |> Map.put_new("id", random_hex(32))
    |> Map.put_new("timestamp", DateTime.utc_now() |> DateTime.to_iso8601())
    |> Map.put_new("serverInstanceId", Application.get_env(:clio, :server_instance_id, "unknown"))
    |> redact_sensitive_data()
  end

  def redact_sensitive_data(data) when is_map(data) do
    sensitive_keys = ~w(secrets password token key jwt_token)

    Map.new(data, fn {k, v} ->
      if k in sensitive_keys and not is_nil(v) and v != "" do
        {k, "[REDACTED]"}
      else
        {k, redact_sensitive_data(v)}
      end
    end)
  end

  def redact_sensitive_data(data) when is_list(data) do
    Enum.map(data, &redact_sensitive_data/1)
  end

  def redact_sensitive_data(data), do: data

  defp random_hex(bytes) do
    :crypto.strong_rand_bytes(bytes) |> Base.encode16(case: :lower)
  end
end
