defmodule Clio.Tags do
  @moduledoc "Tagging context: CRUD, autocomplete, stats, operation tag protection."

  import Ecto.Query
  alias Clio.Repo
  alias Clio.Tags.{Tag, LogTag}

  # ── CRUD ──

  def create_tag(attrs) do
    %Tag{}
    |> Tag.changeset(attrs)
    |> Repo.insert(on_conflict: [set: [updated_at: DateTime.utc_now()]], conflict_target: :name)
  end

  def get_tag(id) do
    case Repo.get(Tag, id) do
      nil -> {:error, :not_found}
      tag -> {:ok, tag}
    end
  end

  def get_tag_by_name(name) do
    name = name |> String.trim() |> String.downcase()
    case Repo.get_by(Tag, name: name) do
      nil -> {:error, :not_found}
      tag -> {:ok, tag}
    end
  end

  def get_or_create(name, opts \\ []) do
    name = name |> String.trim() |> String.downcase()
    category = Keyword.get(opts, :category, "custom")
    color = Keyword.get(opts, :color, "#6B7280")
    created_by = Keyword.get(opts, :created_by, "system")

    attrs = %{name: name, category: category, color: color, created_by: created_by}

    case create_tag(attrs) do
      {:ok, tag} -> {:ok, tag}
      {:error, _} -> get_tag_by_name(name)
    end
  end

  def update_tag(id, attrs) do
    with {:ok, tag} <- get_tag(id),
         :ok <- check_operation_tag_protection(tag) do
      tag
      |> Tag.changeset(attrs)
      |> Repo.update()
    end
  end

  def delete_tag(id) do
    with {:ok, tag} <- get_tag(id),
         :ok <- check_operation_tag_protection(tag) do
      Repo.delete(tag)
    end
  end

  def list_tags do
    Repo.all(from t in Tag, order_by: [asc: t.name])
  end

  # ── Protection ──

  defp check_operation_tag_protection(tag) do
    if Tag.operation_tag?(tag) do
      {:error, :operation_tag_protected}
    else
      :ok
    end
  end

  # ── Autocomplete ──

  def autocomplete(search_term) do
    term = "%#{search_term}%"

    from(t in Tag,
      where: ilike(t.name, ^term),
      order_by: [
        desc: t.name == ^String.downcase(search_term),
        asc: fragment("length(?)", t.name)
      ],
      limit: 20
    )
    |> Repo.all()
  end

  # ── Statistics ──

  def tag_stats do
    from(t in Tag,
      left_join: lt in LogTag, on: lt.tag_id == t.id,
      group_by: t.id,
      select: %{
        tag: t,
        usage_count: count(lt.id),
        last_used: max(lt.tagged_at)
      },
      order_by: [asc: t.name]
    )
    |> Repo.all()
  end

  # ── Log-Tag Association ──

  def add_tag_to_log(log_id, tag_id, tagged_by) do
    %LogTag{}
    |> LogTag.changeset(%{log_id: log_id, tag_id: tag_id, tagged_by: tagged_by})
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:log_id, :tag_id])
  end

  def remove_tag_from_log(log_id, tag_id) do
    log_tag = Repo.get_by(LogTag, log_id: log_id, tag_id: tag_id)

    with {:ok, lt} <- ensure_exists(log_tag),
         :ok <- check_native_operation_tag(lt) do
      Repo.delete(lt)
    end
  end

  def remove_all_tags_from_log(log_id) do
    # Keep the native operation tag (first operation tag by tagged_at)
    native_tag = get_native_operation_tag(log_id)

    query = from lt in LogTag, where: lt.log_id == ^log_id

    query =
      if native_tag do
        from lt in query, where: lt.id != ^native_tag.id
      else
        query
      end

    Repo.delete_all(query)
    :ok
  end

  defp get_native_operation_tag(log_id) do
    from(lt in LogTag,
      join: t in Tag, on: t.id == lt.tag_id,
      where: lt.log_id == ^log_id,
      where: t.category == "operation" and ilike(t.name, "op:%"),
      order_by: [asc: lt.tagged_at],
      limit: 1
    )
    |> Repo.one()
  end

  defp check_native_operation_tag(log_tag) do
    tag = Repo.get(Tag, log_tag.tag_id)

    if Tag.operation_tag?(tag) do
      native = get_native_operation_tag(log_tag.log_id)

      if native && native.id == log_tag.id do
        {:error, :native_operation_tag_protected}
      else
        :ok
      end
    else
      :ok
    end
  end

  # ── Tag Filtering ──

  def get_logs_by_tag_ids(tag_ids) when is_list(tag_ids) do
    from(lt in LogTag,
      where: lt.tag_id in ^tag_ids,
      join: l in assoc(lt, :log),
      distinct: l.id,
      select: l,
      preload: [:tags, :log_tags, :evidence_files]
    )
    |> Repo.all()
  end

  def get_logs_by_tag_names(tag_names) when is_list(tag_names) do
    names = Enum.map(tag_names, &String.downcase/1)

    from(lt in LogTag,
      join: t in Tag, on: t.id == lt.tag_id,
      where: t.name in ^names,
      join: l in assoc(lt, :log),
      distinct: l.id,
      select: l,
      preload: [:tags, :log_tags, :evidence_files]
    )
    |> Repo.all()
  end

  defp ensure_exists(nil), do: {:error, :not_found}
  defp ensure_exists(record), do: {:ok, record}
end
