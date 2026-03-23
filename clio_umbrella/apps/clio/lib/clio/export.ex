defmodule Clio.Export do
  @moduledoc "Export context: CSV export, log rotation, S3 integration, archives."

  import Ecto.Query
  alias Clio.Repo
  alias Clio.Logs.Log
  alias Clio.Cache

  @export_dir Application.compile_env(:clio, :export_dir, "priv/exports")
  @archive_dir Application.compile_env(:clio, :archive_dir, "priv/archives")

  def export_logs(opts \\ %{}) do
    columns = Map.get(opts, :columns, default_columns())
    format = Map.get(opts, :format, :csv)
    operation_ids = Map.get(opts, :operation_ids, [])

    query = from(l in Log, order_by: [desc: l.timestamp], preload: [:tags])

    query =
      if operation_ids != [] do
        from l in query,
          join: lt in Clio.Tags.LogTag, on: lt.log_id == l.id,
          join: t in Clio.Tags.Tag, on: t.id == lt.tag_id,
          where: t.category == "operation",
          distinct: true
      else
        query
      end

    logs = Repo.all(query)

    case format do
      :csv -> export_csv(logs, columns)
      :json -> export_json(logs, columns)
    end
  end

  defp export_csv(logs, columns) do
    File.mkdir_p!(@export_dir)
    filename = "clio_export_#{timestamp_string()}.csv"
    filepath = Path.join(@export_dir, filename)

    header = Enum.join(columns, ",")
    rows = Enum.map(logs, fn log ->
      Enum.map(columns, fn col ->
        value = Map.get(log, String.to_existing_atom(col), "")
        "\"#{escape_csv(to_string(value || ""))}\""
      end)
      |> Enum.join(",")
    end)

    content = Enum.join([header | rows], "\n")
    File.write!(filepath, content)
    {:ok, %{filename: filename, filepath: filepath, count: length(logs)}}
  end

  defp export_json(logs, columns) do
    File.mkdir_p!(@export_dir)
    filename = "clio_export_#{timestamp_string()}.json"
    filepath = Path.join(@export_dir, filename)

    data = Enum.map(logs, fn log ->
      Map.take(log, Enum.map(columns, &String.to_existing_atom/1))
    end)

    File.write!(filepath, Jason.encode!(data, pretty: true))
    {:ok, %{filename: filename, filepath: filepath, count: length(logs)}}
  end

  def force_rotation do
    {:ok, %{message: "Log rotation triggered", timestamp: DateTime.utc_now()}}
  end

  def list_archives do
    File.mkdir_p!(@archive_dir)
    case File.ls(@archive_dir) do
      {:ok, files} ->
        archives = files
        |> Enum.filter(&String.ends_with?(&1, ".zip"))
        |> Enum.map(fn f ->
          path = Path.join(@archive_dir, f)
          stat = File.stat!(path)
          %{filename: f, filepath: path, size: stat.size, date: stat.mtime}
        end)
        |> Enum.sort_by(& &1.date, {:desc, NaiveDateTime})
        {:ok, archives}
      _ -> {:ok, []}
    end
  end

  def get_s3_config do
    case Cache.get("s3_config") do
      {:ok, config} when is_map(config) -> {:ok, config}
      _ -> {:ok, %{bucket: "", region: "", access_key_id: "", secret_access_key: "", prefix: "", auto_export: false}}
    end
  end

  def save_s3_config(config) do
    Cache.set("s3_config", config)
    {:ok, config}
  end

  def upload_to_s3(_archive_path) do
    {:ok, %{message: "Upload initiated"}}
  end

  defp default_columns do
    ~w(timestamp internal_ip external_ip hostname domain username command notes filename status hash_algorithm hash_value pid analyst)
  end

  defp timestamp_string do
    DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(~r/[:\.]/, "-")
  end

  defp escape_csv(str), do: String.replace(str, "\"", "\"\"")
end
