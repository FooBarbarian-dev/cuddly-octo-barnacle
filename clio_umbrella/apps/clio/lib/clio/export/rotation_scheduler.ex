defmodule Clio.Export.RotationScheduler do
  @moduledoc "GenServer that periodically rotates audit log files when they exceed max size."
  use GenServer

  alias Clio.Audit.Writer

  @rotation_interval :timer.hours(1)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_rotation()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:rotate, state) do
    rotate_logs()
    schedule_rotation()
    {:noreply, state}
  end

  defp rotate_logs do
    data_dir = Application.get_env(:clio, :data_dir, "data")
    categories = ~w(security data system audit)

    for category <- categories do
      path = Path.join(data_dir, "#{category}_logs.json")

      if File.exists?(path) do
        case File.read(path) do
          {:ok, content} ->
            entries = Jason.decode!(content)

            if length(entries) >= 10_000 do
              timestamp = DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(~r/[:\.]/, "-")
              archive_path = Path.join(data_dir, "#{category}_logs_#{timestamp}.json")
              File.rename!(path, archive_path)
              File.write!(path, "[]")
            end

          _ ->
            :ok
        end
      end
    end
  end

  defp schedule_rotation do
    Process.send_after(self(), :rotate, @rotation_interval)
  end
end
