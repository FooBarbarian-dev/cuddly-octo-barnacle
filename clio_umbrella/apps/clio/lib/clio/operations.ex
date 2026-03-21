defmodule Clio.Operations do
  @moduledoc "Operations context: CRUD, user assignment, active operation management."

  import Ecto.Query
  alias Clio.Repo
  alias Clio.Operations.{Operation, UserOperation}

  # ── Create ──

  def create_operation(attrs) do
    %Operation{}
    |> Operation.changeset(attrs)
    |> Repo.insert()
  end

  # ── Read ──

  def get_operation(id) do
    case Repo.get(Operation, id) do
      nil -> {:error, :not_found}
      op -> {:ok, Repo.preload(op, [:tag, :user_operations])}
    end
  end

  def list_operations do
    from(o in Operation, order_by: [desc: o.inserted_at], preload: [:tag])
    |> Repo.all()
  end

  def list_active_operations do
    from(o in Operation, where: o.is_active == true, order_by: [asc: o.name], preload: [:tag])
    |> Repo.all()
  end

  # ── Update ──

  def update_operation(id, attrs) do
    with {:ok, op} <- get_operation(id) do
      op
      |> Operation.changeset(attrs)
      |> Repo.update()
    end
  end

  def deactivate_operation(id) do
    update_operation(id, %{is_active: false})
  end

  # ── Delete ──

  def delete_operation(id) do
    with {:ok, op} <- get_operation(id) do
      Repo.delete(op)
    end
  end

  # ── User Assignment ──

  def assign_user(operation_id, username, assigned_by) do
    attrs = %{
      operation_id: operation_id,
      username: username,
      assigned_by: assigned_by,
      is_primary: false
    }

    %UserOperation{}
    |> UserOperation.changeset(attrs)
    |> Repo.insert(on_conflict: :nothing, conflict_target: [:username, :operation_id])
  end

  def unassign_user(operation_id, username) do
    case Repo.get_by(UserOperation, operation_id: operation_id, username: username) do
      nil -> {:error, :not_found}
      uo -> Repo.delete(uo)
    end
  end

  def set_primary_operation(username, operation_id) do
    Repo.transaction(fn ->
      # Unset all primary flags for this user
      from(uo in UserOperation, where: uo.username == ^username and uo.is_primary == true)
      |> Repo.update_all(set: [is_primary: false])

      # Set the new primary
      case Repo.get_by(UserOperation, username: username, operation_id: operation_id) do
        nil ->
          Repo.rollback(:not_assigned)

        uo ->
          uo
          |> Ecto.Changeset.change(%{is_primary: true, last_accessed: DateTime.utc_now()})
          |> Repo.update!()
      end
    end)
  end

  # ── Active Operation ──

  def get_active_operation(username) do
    query =
      from uo in UserOperation,
        join: o in Operation, on: o.id == uo.operation_id,
        where: uo.username == ^username and uo.is_primary == true and o.is_active == true,
        preload: [operation: :tag],
        limit: 1

    case Repo.one(query) do
      nil -> {:ok, nil}
      uo -> {:ok, %{tag_id: uo.operation.tag_id, operation: uo.operation}}
    end
  end

  def get_user_operations(username) do
    from(uo in UserOperation,
      where: uo.username == ^username,
      join: o in assoc(uo, :operation),
      where: o.is_active == true,
      preload: [operation: :tag],
      order_by: [desc: uo.is_primary, desc: uo.last_accessed]
    )
    |> Repo.all()
  end
end
