defmodule Clio.Logs do
  @moduledoc "Log management context: CRUD, search, locking, auto-tagging, duplicate detection."

  import Ecto.Query
  alias Clio.Repo
  alias Clio.Logs.Log
  alias Clio.Tags
  alias Clio.Tags.LogTag
  alias Clio.Operations

  @duplicate_window_seconds 5

  # ── Create ──

  def create_log(attrs, %{username: username} = user) do
    attrs = Map.put(attrs, :analyst, username)

    changeset = Log.changeset(%Log{}, attrs)

    with {:ok, _} <- check_no_duplicate(attrs),
         {:ok, log} <- Repo.insert(changeset) do
      # Auto-tag with active operation
      auto_tag_with_operation(log.id, username, user)
      {:ok, Repo.preload(log, [:tags, :log_tags, :evidence_files])}
    end
  end

  defp check_no_duplicate(attrs) do
    timestamp = Map.get(attrs, :timestamp) || Map.get(attrs, "timestamp")
    command = Map.get(attrs, :command) || Map.get(attrs, "command")
    hostname = Map.get(attrs, :hostname) || Map.get(attrs, "hostname")
    username = Map.get(attrs, :username) || Map.get(attrs, "username")

    if timestamp && command do
      window_start = DateTime.add(timestamp, -@duplicate_window_seconds, :second)

      query =
        from l in Log,
          where: l.timestamp >= ^window_start and l.timestamp <= ^timestamp,
          where: l.command == ^command,
          where: l.hostname == ^(hostname || ""),
          where: l.username == ^(username || ""),
          limit: 1

      case Repo.one(query) do
        nil -> {:ok, :no_duplicate}
        existing -> {:error, {:duplicate, existing.id}}
      end
    else
      {:ok, :no_duplicate}
    end
  end

  defp auto_tag_with_operation(log_id, username, user) do
    case Operations.get_active_operation(username) do
      {:ok, operation} when not is_nil(operation) ->
        if operation.tag_id do
          attrs = %{log_id: log_id, tag_id: operation.tag_id, tagged_by: username}
          %LogTag{}
          |> LogTag.changeset(attrs)
          |> Repo.insert(on_conflict: :nothing, conflict_target: [:log_id, :tag_id])
        end

      _ ->
        :ok
    end
  rescue
    _ -> :ok
  end

  # ── Read ──

  def get_log(id) do
    case Repo.get(Log, id) do
      nil -> {:error, :not_found}
      log -> {:ok, Repo.preload(log, [:tags, :log_tags, :evidence_files])}
    end
  end

  def list_logs(user, opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    query =
      from l in Log,
        order_by: [desc: l.timestamp, desc: l.id],
        limit: ^limit,
        offset: ^offset,
        preload: [:tags, :log_tags, :evidence_files]

    query
    |> apply_operation_filter(user)
    |> apply_search_filters(opts)
    |> Repo.all()
  end

  defp apply_operation_filter(query, %{role: :admin} = user) do
    case Operations.get_active_operation(user.username) do
      {:ok, nil} -> query
      {:ok, op} ->
        from l in query,
          join: lt in LogTag, on: lt.log_id == l.id,
          where: lt.tag_id == ^op.tag_id,
          distinct: true
      _ -> query
    end
  end

  defp apply_operation_filter(query, %{username: username}) do
    case Operations.get_active_operation(username) do
      {:ok, op} when not is_nil(op) ->
        from l in query,
          join: lt in LogTag, on: lt.log_id == l.id,
          where: lt.tag_id == ^op.tag_id,
          distinct: true
      _ ->
        from l in query, where: false
    end
  end

  defp apply_search_filters(query, opts) do
    query
    |> maybe_filter(:hostname, Keyword.get(opts, :hostname))
    |> maybe_filter(:internal_ip, Keyword.get(opts, :internal_ip))
    |> maybe_filter(:command, Keyword.get(opts, :command))
    |> maybe_filter(:username, Keyword.get(opts, :username))
    |> maybe_filter_date_from(Keyword.get(opts, :date_from))
    |> maybe_filter_date_to(Keyword.get(opts, :date_to))
  end

  defp maybe_filter(query, _field, nil), do: query
  defp maybe_filter(query, :hostname, val), do: from(l in query, where: ilike(l.hostname, ^"%#{val}%"))
  defp maybe_filter(query, :internal_ip, val), do: from(l in query, where: l.internal_ip == ^val)
  defp maybe_filter(query, :command, val), do: from(l in query, where: ilike(l.command, ^"%#{val}%"))
  defp maybe_filter(query, :username, val), do: from(l in query, where: ilike(l.username, ^"%#{val}%"))

  defp maybe_filter_date_from(query, nil), do: query
  defp maybe_filter_date_from(query, date), do: from(l in query, where: l.timestamp >= ^date)

  defp maybe_filter_date_to(query, nil), do: query
  defp maybe_filter_date_to(query, date), do: from(l in query, where: l.timestamp <= ^date)

  # ── Update ──

  def update_log(id, attrs, user) do
    with {:ok, log} <- get_log(id),
         :ok <- check_lock(log, user),
         {:ok, updated} <- log |> Log.changeset(attrs) |> Repo.update() do
      {:ok, Repo.preload(updated, [:tags, :log_tags, :evidence_files], force: true)}
    end
  end

  # ── Delete ──

  def delete_log(id, %{role: :admin}) do
    with {:ok, log} <- get_log(id) do
      # Delete evidence files from disk
      delete_evidence_files(log)
      Repo.delete(log)
    end
  end

  def delete_log(_id, _user), do: {:error, :unauthorized}

  def bulk_delete(ids, %{role: :admin}) when is_list(ids) do
    logs = Repo.all(from l in Log, where: l.id in ^ids, preload: [:evidence_files])
    Enum.each(logs, &delete_evidence_files/1)

    {count, _} = Repo.delete_all(from l in Log, where: l.id in ^ids)
    {:ok, count}
  end

  def bulk_delete(_ids, _user), do: {:error, :unauthorized}

  defp delete_evidence_files(log) do
    log = Repo.preload(log, :evidence_files)
    Enum.each(log.evidence_files, fn ef ->
      File.rm(ef.filepath)
    end)
  end

  # ── Locking ──

  def lock_log(id, username) do
    with {:ok, log} <- get_log(id) do
      cond do
        log.locked and log.locked_by == username ->
          {:ok, log}

        log.locked ->
          {:error, :locked_by_another_user}

        true ->
          log
          |> Ecto.Changeset.change(%{locked: true, locked_by: username})
          |> Repo.update()
      end
    end
  end

  def unlock_log(id, user) do
    with {:ok, log} <- get_log(id),
         :ok <- check_unlock_permission(log, user) do
      log
      |> Ecto.Changeset.change(%{locked: false, locked_by: nil})
      |> Repo.update()
    end
  end

  defp check_lock(log, user) do
    cond do
      not log.locked -> :ok
      log.locked_by == user.username -> :ok
      user.role == :admin -> :ok
      true -> {:error, :locked_by_another_user}
    end
  end

  defp check_unlock_permission(log, user) do
    cond do
      log.locked_by == user.username -> :ok
      user.role == :admin -> :ok
      true -> {:error, :unauthorized}
    end
  end

  # ── Search ──

  def search_logs(params, user) do
    opts =
      Enum.reduce(params, [], fn
        {"hostname", v}, acc -> [{:hostname, v} | acc]
        {"internal_ip", v}, acc -> [{:internal_ip, v} | acc]
        {"command", v}, acc -> [{:command, v} | acc]
        {"username", v}, acc -> [{:username, v} | acc]
        {"dateFrom", v}, acc -> [{:date_from, parse_datetime(v)} | acc]
        {"dateTo", v}, acc -> [{:date_to, parse_datetime(v)} | acc]
        {"limit", v}, acc -> [{:limit, String.to_integer(v)} | acc]
        _, acc -> acc
      end)

    list_logs(user, opts)
  end

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> dt
      _ -> nil
    end
  end

  defp parse_datetime(value), do: value
end
