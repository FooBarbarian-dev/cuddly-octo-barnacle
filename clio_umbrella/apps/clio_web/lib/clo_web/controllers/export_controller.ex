defmodule CloWeb.ExportController do
  use CloWeb, :controller

  alias Clio.Logs
  alias Clio.Audit

  def export_csv(conn, params) do
    user = conn.assigns.current_user
    logs = Logs.search_logs(params, user)

    csv_data = generate_csv(logs)
    Audit.log_data("export_csv", user.username, %{"count" => length(logs)})

    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"clio_export_#{timestamp()}.csv\"")
    |> send_resp(200, csv_data)
  end

  def export_json(conn, params) do
    user = conn.assigns.current_user
    logs = Logs.search_logs(params, user)

    Audit.log_data("export_json", user.username, %{"count" => length(logs)})

    json_data =
      Enum.map(logs, fn log ->
        %{
          id: log.id,
          timestamp: log.timestamp,
          hostname: log.hostname,
          internal_ip: log.internal_ip,
          external_ip: log.external_ip,
          username: log.username,
          command: log.command,
          notes: log.notes,
          status: log.status,
          analyst: log.analyst,
          tags: Enum.map(log.tags, & &1.name)
        }
      end)

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("content-disposition", "attachment; filename=\"clio_export_#{timestamp()}.json\"")
    |> send_resp(200, Jason.encode!(%{exported_at: DateTime.utc_now(), data: json_data}))
  end

  def audit_logs(conn, %{"category" => category}) when category in ~w(security data system audit) do
    data_dir = Application.get_env(:clio, :data_dir, "data")
    path = Path.join(data_dir, "#{category}_logs.json")

    case File.read(path) do
      {:ok, content} -> json(conn, %{data: Jason.decode!(content)})
      {:error, _} -> json(conn, %{data: []})
    end
  end

  def audit_logs(conn, _params) do
    conn |> put_status(400) |> json(%{error: "Invalid category. Must be one of: security, data, system, audit"})
  end

  defp generate_csv(logs) do
    headers = "id,timestamp,hostname,internal_ip,external_ip,username,command,notes,status,analyst,tags\r\n"

    rows =
      Enum.map(logs, fn log ->
        tags = Enum.map_join(log.tags, "|", & &1.name)

        [
          log.id, log.timestamp, log.hostname, log.internal_ip, log.external_ip,
          log.username, csv_escape(log.command), csv_escape(log.notes),
          log.status, log.analyst, tags
        ]
        |> Enum.map_join(",", &to_string(&1 || ""))
      end)
      |> Enum.join("\r\n")

    headers <> rows
  end

  defp csv_escape(nil), do: ""
  defp csv_escape(value) do
    # Prevent CSV formula injection by prefixing dangerous chars with a single quote
    value = if String.starts_with?(value, ["=", "+", "-", "@", "\t", "\r"]) do
      "'" <> value
    else
      value
    end

    if String.contains?(value, [",", "\"", "\n"]) do
      "\"#{String.replace(value, "\"", "\"\"")}\""
    else
      value
    end
  end

  defp timestamp do
    DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(~r/[:\.]/, "-")
  end
end
