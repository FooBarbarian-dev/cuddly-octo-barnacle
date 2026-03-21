defmodule CloWeb.TagController do
  use CloWeb, :controller

  alias Clio.Tags

  def index(conn, _params) do
    tags = Tags.list_tags()
    json(conn, %{data: Enum.map(tags, &serialize_tag/1)})
  end

  def show(conn, %{"id" => id}) do
    case Tags.get_tag(id) do
      {:ok, tag} -> json(conn, %{data: serialize_tag(tag)})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{error: "Tag not found"})
    end
  end

  def create(conn, %{"tag" => tag_params}) do
    case Tags.create_tag(tag_params) do
      {:ok, tag} ->
        conn |> put_status(201) |> json(%{data: serialize_tag(tag)})

      {:error, changeset} ->
        conn |> put_status(422) |> json(%{error: "Validation failed", details: format_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id, "tag" => tag_params}) do
    case Tags.update_tag(id, tag_params) do
      {:ok, tag} -> json(conn, %{data: serialize_tag(tag)})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{error: "Tag not found"})
      {:error, :operation_tag_protected} -> conn |> put_status(403) |> json(%{error: "Operation tags cannot be modified"})
      {:error, changeset} -> conn |> put_status(422) |> json(%{error: "Validation failed", details: format_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Tags.delete_tag(id) do
      {:ok, _} -> json(conn, %{message: "Tag deleted"})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{error: "Tag not found"})
      {:error, :operation_tag_protected} -> conn |> put_status(403) |> json(%{error: "Operation tags cannot be deleted"})
    end
  end

  def autocomplete(conn, %{"q" => query}) do
    tags = Tags.autocomplete(query)
    json(conn, %{data: Enum.map(tags, &serialize_tag/1)})
  end

  def stats(conn, _params) do
    stats = Tags.tag_stats()
    json(conn, %{data: Enum.map(stats, fn s -> Map.put(serialize_tag(s.tag), :usage_count, s.usage_count) end)})
  end

  def add_to_log(conn, %{"log_id" => log_id, "tag_id" => tag_id}) do
    user = conn.assigns.current_user

    case Tags.add_tag_to_log(log_id, tag_id, user.username) do
      {:ok, _} -> json(conn, %{message: "Tag added"})
      {:error, changeset} -> conn |> put_status(422) |> json(%{error: format_errors(changeset)})
    end
  end

  def remove_from_log(conn, %{"log_id" => log_id, "tag_id" => tag_id}) do
    case Tags.remove_tag_from_log(log_id, tag_id) do
      {:ok, _} -> json(conn, %{message: "Tag removed"})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{error: "Tag association not found"})
      {:error, :native_operation_tag_protected} -> conn |> put_status(403) |> json(%{error: "Native operation tag cannot be removed"})
    end
  end

  defp serialize_tag(tag) do
    %{
      id: tag.id,
      name: tag.name,
      color: tag.color,
      category: tag.category,
      description: tag.description,
      is_default: tag.is_default
    }
  end

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end

  defp format_errors(error), do: inspect(error)
end
