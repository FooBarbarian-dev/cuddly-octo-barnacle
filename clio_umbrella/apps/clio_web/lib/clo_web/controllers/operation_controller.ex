defmodule CloWeb.OperationController do
  @moduledoc "Controller for operation CRUD, user assignment, and active operation management."
  use CloWeb, :controller

  alias Clio.Operations
  alias Clio.Audit

  def index(conn, _params) do
    operations = Operations.list_operations()
    json(conn, %{data: Enum.map(operations, &serialize_operation/1)})
  end

  def show(conn, %{"id" => id}) do
    case Operations.get_operation(id) do
      {:ok, op} -> json(conn, %{data: serialize_operation(op)})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{error: "Operation not found"})
    end
  end

  def create(conn, %{"operation" => op_params}) do
    user = conn.assigns.current_user
    attrs = Map.put(op_params, "created_by", user.username)

    case Operations.create_operation(attrs) do
      {:ok, op} ->
        Audit.log_data("operation_created", user.username, %{"operation_id" => op.id})
        conn |> put_status(201) |> json(%{data: serialize_operation(op)})

      {:error, changeset} ->
        conn |> put_status(422) |> json(%{error: "Validation failed", details: format_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id, "operation" => op_params}) do
    case Operations.update_operation(id, op_params) do
      {:ok, op} -> json(conn, %{data: serialize_operation(op)})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{error: "Operation not found"})
      {:error, changeset} -> conn |> put_status(422) |> json(%{error: "Validation failed", details: format_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Operations.delete_operation(id) do
      {:ok, _} -> json(conn, %{message: "Operation deleted"})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{error: "Operation not found"})
    end
  end

  def assign_user(conn, %{"id" => id, "username" => username}) do
    user = conn.assigns.current_user

    case Operations.assign_user(id, username, user.username) do
      {:ok, _} -> json(conn, %{message: "User assigned"})
      {:error, changeset} -> conn |> put_status(422) |> json(%{error: format_errors(changeset)})
    end
  end

  def unassign_user(conn, %{"id" => id, "username" => username}) do
    case Operations.unassign_user(id, username) do
      {:ok, _} -> json(conn, %{message: "User unassigned"})
      {:error, :not_found} -> conn |> put_status(404) |> json(%{error: "Assignment not found"})
    end
  end

  def set_active(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case Integer.parse(id) do
      {op_id, ""} ->
        case Operations.set_primary_operation(user.username, op_id) do
          {:ok, _} -> json(conn, %{message: "Active operation set"})
          {:error, :not_assigned} -> conn |> put_status(422) |> json(%{error: "Not assigned to this operation"})
        end

      _ ->
        conn |> put_status(400) |> json(%{error: "Invalid operation ID"})
    end
  end

  def my_operations(conn, _params) do
    user = conn.assigns.current_user
    user_ops = Operations.get_user_operations(user.username)

    json(conn, %{
      data: Enum.map(user_ops, fn uo ->
        serialize_operation(uo.operation) |> Map.put(:is_primary, uo.is_primary)
      end)
    })
  end

  defp serialize_operation(op) do
    %{
      id: op.id,
      name: op.name,
      description: op.description,
      is_active: op.is_active,
      created_by: op.created_by,
      tag: serialize_tag(op),
      inserted_at: op.inserted_at,
      updated_at: op.updated_at
    }
  end

  defp serialize_tag(%{tag: %Ecto.Association.NotLoaded{}}), do: nil
  defp serialize_tag(%{tag: nil}), do: nil
  defp serialize_tag(%{tag: tag}), do: %{id: tag.id, name: tag.name, color: tag.color}

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end)
  end

  defp format_errors(error), do: inspect(error)
end
