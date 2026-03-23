defmodule Clio.Templates do
  @moduledoc "Templates context: CRUD for reusable log entry templates."

  import Ecto.Query
  alias Clio.Repo
  alias Clio.Templates.LogTemplate

  def list do
    Repo.all(from t in LogTemplate, order_by: [desc: t.inserted_at])
  end

  def get(id) do
    case Repo.get(LogTemplate, id) do
      nil -> {:error, :not_found}
      template -> {:ok, template}
    end
  end

  def create(attrs, username) do
    attrs = Map.put(attrs, :created_by, username)

    %LogTemplate{}
    |> LogTemplate.changeset(attrs)
    |> Repo.insert()
  end

  def update(id, attrs, _username) do
    with {:ok, template} <- get(id) do
      template
      |> LogTemplate.changeset(attrs)
      |> Repo.update()
    end
  end

  def delete(id) do
    with {:ok, template} <- get(id) do
      Repo.delete(template)
    end
  end
end
