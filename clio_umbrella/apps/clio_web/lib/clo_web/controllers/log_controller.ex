defmodule CloWeb.LogController do
  @moduledoc "Controller for log entry CRUD, bulk operations, locking, and search."
  use CloWeb, :controller

  alias Clio.Logs
  alias Clio.Sanitizer
  alias Clio.Audit

  def index(conn, params) do
    user = conn.assigns.current_user
    logs = Logs.search_logs(params, user)
    json(conn, %{data: Enum.map(logs, &serialize_log/1)})
  end

  def show(conn, %{"id" => id}) do
    case Logs.get_log(id) do
      {:ok, log} -> json(conn, %{data: serialize_log(log)})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{error: "Log not found"})
    end
  end

  def create(conn, %{"log" => log_params}) do
    user = conn.assigns.current_user
    sanitized = Sanitizer.sanitize_params(log_params)

    case Logs.create_log(sanitized, user) do
      {:ok, log} ->
        Audit.log_data("log_created", user.username, %{"log_id" => log.id})

        conn
        |> put_status(201)
        |> json(%{data: serialize_log(log)})

      {:error, {:duplicate, existing_id}} ->
        conn
        |> put_status(409)
        |> json(%{error: "Duplicate log entry", existing_id: existing_id})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{error: "Validation failed", details: format_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id, "log" => log_params}) do
    user = conn.assigns.current_user
    sanitized = Sanitizer.sanitize_params(log_params)

    case Logs.update_log(id, sanitized, user) do
      {:ok, log} ->
        Audit.log_data("log_updated", user.username, %{"log_id" => log.id})
        json(conn, %{data: serialize_log(log)})

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{error: "Log not found"})

      {:error, :locked_by_another_user} ->
        conn |> put_status(423) |> json(%{error: "Log is locked by another user"})

      {:error, changeset} ->
        conn |> put_status(422) |> json(%{error: "Validation failed", details: format_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Logs.delete_log(id, user) do
      {:ok, _} ->
        Audit.log_data("log_deleted", user.username, %{"log_id" => id})
        json(conn, %{message: "Log deleted"})

      {:error, :unauthorized} ->
        conn |> put_status(403) |> json(%{error: "Admin access required"})

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{error: "Log not found"})
    end
  end

  def bulk_delete(conn, %{"ids" => ids}) do
    user = conn.assigns.current_user

    case Logs.bulk_delete(ids, user) do
      {:ok, count} ->
        Audit.log_data("logs_bulk_deleted", user.username, %{"count" => count})
        json(conn, %{message: "Deleted #{count} logs"})

      {:error, :unauthorized} ->
        conn |> put_status(403) |> json(%{error: "Admin access required"})
    end
  end

  def lock(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Logs.lock_log(id, user.username) do
      {:ok, log} -> json(conn, %{data: serialize_log(log)})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{error: "Log not found"})
      {:error, :locked_by_another_user} -> conn |> put_status(423) |> json(%{error: "Log is locked by another user"})
    end
  end

  def unlock(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Logs.unlock_log(id, user) do
      {:ok, log} -> json(conn, %{data: serialize_log(log)})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{error: "Log not found"})
      {:error, :unauthorized} -> conn |> put_status(403) |> json(%{error: "Unauthorized"})
    end
  end

  defp serialize_log(log) do
    %{
      id: log.id,
      timestamp: log.timestamp,
      internal_ip: log.internal_ip,
      external_ip: log.external_ip,
      mac_address: log.mac_address,
      hostname: log.hostname,
      domain: log.domain,
      username: log.username,
      command: log.command,
      notes: log.notes,
      filename: log.filename,
      status: log.status,
      hash_algorithm: log.hash_algorithm,
      hash_value: log.hash_value,
      pid: log.pid,
      analyst: log.analyst,
      locked: log.locked,
      locked_by: log.locked_by,
      tags: serialize_tags(log),
      evidence_files: serialize_evidence(log),
      inserted_at: log.inserted_at,
      updated_at: log.updated_at
    }
  end

  defp serialize_tags(%{tags: %Ecto.Association.NotLoaded{}}), do: []
  defp serialize_tags(%{tags: tags}), do: Enum.map(tags, &%{id: &1.id, name: &1.name, color: &1.color, category: &1.category})

  defp serialize_evidence(%{evidence_files: %Ecto.Association.NotLoaded{}}), do: []
  defp serialize_evidence(%{evidence_files: files}), do: Enum.map(files, &%{id: &1.id, filename: &1.original_filename, file_type: &1.file_type, file_size: &1.file_size})

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  defp format_errors(error), do: inspect(error)
end
