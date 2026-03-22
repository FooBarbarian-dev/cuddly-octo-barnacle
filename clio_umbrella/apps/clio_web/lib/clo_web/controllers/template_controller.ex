defmodule CloWeb.TemplateController do
  use CloWeb, :controller

  alias Clio.Repo
  alias Clio.Templates.LogTemplate
  import Ecto.Query

  def index(conn, _params) do
    templates = Repo.all(from t in LogTemplate, order_by: [asc: t.name])
    json(conn, %{data: Enum.map(templates, &serialize/1)})
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(LogTemplate, id) do
      nil -> conn |> put_status(404) |> json(%{error: "Template not found"})
      template -> json(conn, %{data: serialize(template)})
    end
  end

  def create(conn, %{"template" => params}) do
    user = conn.assigns.current_user
    attrs = Map.put(params, "created_by", user.username)

    case %LogTemplate{} |> LogTemplate.changeset(attrs) |> Repo.insert() do
      {:ok, template} ->
        conn |> put_status(201) |> json(%{data: serialize(template)})

      {:error, changeset} ->
        conn |> put_status(422) |> json(%{error: format_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id, "template" => params}) do
    case Repo.get(LogTemplate, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "Template not found"})

      template ->
        case template |> LogTemplate.changeset(params) |> Repo.update() do
          {:ok, updated} -> json(conn, %{data: serialize(updated)})
          {:error, changeset} -> conn |> put_status(422) |> json(%{error: format_errors(changeset)})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    case Repo.get(LogTemplate, id) do
      nil ->
        conn |> put_status(404) |> json(%{error: "Template not found"})

      template ->
        {:ok, _} = Repo.delete(template)
        json(conn, %{message: "Template deleted"})
    end
  end

  defp serialize(template) do
    %{
      id: template.id,
      name: template.name,
      template_data: template.template_data,
      created_by: template.created_by,
      inserted_at: template.inserted_at,
      updated_at: template.updated_at
    }
  end

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end
end
