defmodule Clio.RelationsContext do
  @moduledoc "Relations context: queries for relationships, file status, and analysis."

  import Ecto.Query
  alias Clio.Repo
  alias Clio.Relations.{Relation, FileStatus, FileStatusHistory}

  # ── Relations ──

  def list_relations(opts \\ []) do
    type = Keyword.get(opts, :type)

    query = from(r in Relation, order_by: [desc: r.connection_count])

    query =
      if type do
        from r in query, where: r.source_type == ^type or r.target_type == ^type
      else
        query
      end

    Repo.all(query)
  end

  def get_by_type(source_type, target_type) do
    from(r in Relation,
      where: r.source_type == ^source_type and r.target_type == ^target_type,
      order_by: [desc: r.connection_count]
    )
    |> Repo.all()
  end

  def get_commands(opts \\ []) do
    username = Keyword.get(opts, :username)

    query =
      from(r in Relation,
        where: r.source_type == "username" and r.target_type == "command",
        order_by: [desc: r.last_seen]
      )

    query =
      if username do
        from r in query, where: r.source_value == ^username
      else
        query
      end

    Repo.all(query)
  end

  def get_mac_addresses(_opts \\ []) do
    from(r in Relation,
      where: r.source_type == "mac_address" or r.target_type == "mac_address",
      order_by: [desc: r.last_seen]
    )
    |> Repo.all()
  end

  def trigger_analysis do
    {:ok, %{message: "Analysis triggered", timestamp: DateTime.utc_now()}}
  end

  # ── File Status ──

  def list_file_statuses(opts \\ []) do
    query = from(fs in FileStatus, order_by: [desc: fs.last_seen])

    query = maybe_filter_status(query, Keyword.get(opts, :status))
    query = maybe_filter_hostname(query, Keyword.get(opts, :hostname))
    query = maybe_filter_analyst(query, Keyword.get(opts, :analyst))

    Repo.all(query)
  end

  def get_file_status(id) do
    case Repo.get(FileStatus, id) do
      nil -> {:error, :not_found}
      fs -> {:ok, fs}
    end
  end

  def get_file_history(filename) do
    from(h in FileStatusHistory,
      where: h.filename == ^filename,
      order_by: [desc: h.timestamp]
    )
    |> Repo.all()
  end

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, "all"), do: query
  defp maybe_filter_status(query, status), do: from(f in query, where: f.status == ^status)

  defp maybe_filter_hostname(query, nil), do: query
  defp maybe_filter_hostname(query, ""), do: query
  defp maybe_filter_hostname(query, hostname), do: from(f in query, where: ilike(f.hostname, ^"%#{hostname}%"))

  defp maybe_filter_analyst(query, nil), do: query
  defp maybe_filter_analyst(query, ""), do: query
  defp maybe_filter_analyst(query, analyst), do: from(f in query, where: ilike(f.analyst, ^"%#{analyst}%"))
end
