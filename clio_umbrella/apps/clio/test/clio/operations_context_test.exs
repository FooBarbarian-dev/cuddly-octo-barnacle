defmodule Clio.OperationsContextTest do
  use Clio.DataCase, async: true

  alias Clio.Operations

  describe "create_operation/1" do
    test "creates an operation" do
      attrs = %{name: "Thunderstrike", created_by: "admin"}
      assert {:ok, op} = Operations.create_operation(attrs)
      assert op.name == "Thunderstrike"
      assert op.is_active == true
    end

    test "requires name and created_by" do
      assert {:error, changeset} = Operations.create_operation(%{})
      errors = errors_on(changeset)
      assert Map.has_key?(errors, :name)
      assert Map.has_key?(errors, :created_by)
    end
  end

  describe "get_operation/1" do
    test "returns operation with preloads" do
      {:ok, op} = Operations.create_operation(%{name: "TestOp", created_by: "admin"})
      assert {:ok, found} = Operations.get_operation(op.id)
      assert found.name == "TestOp"
    end

    test "returns not_found for missing" do
      assert {:error, :not_found} = Operations.get_operation(999_999)
    end
  end

  describe "list_operations/0" do
    test "returns all operations" do
      {:ok, _} = Operations.create_operation(%{name: "Op1", created_by: "admin"})
      {:ok, _} = Operations.create_operation(%{name: "Op2", created_by: "admin"})
      ops = Operations.list_operations()
      assert length(ops) >= 2
    end
  end

  describe "list_active_operations/0" do
    test "only returns active operations" do
      {:ok, op} = Operations.create_operation(%{name: "ActiveOp", created_by: "admin"})
      {:ok, _} = Operations.update_operation(op.id, %{is_active: false})
      {:ok, _} = Operations.create_operation(%{name: "StillActive", created_by: "admin"})

      active = Operations.list_active_operations()
      names = Enum.map(active, & &1.name)
      assert "StillActive" in names
      refute "ActiveOp" in names
    end
  end

  describe "update_operation/2" do
    test "updates operation attributes" do
      {:ok, op} = Operations.create_operation(%{name: "Original", created_by: "admin"})
      assert {:ok, updated} = Operations.update_operation(op.id, %{description: "Updated desc"})
      assert updated.description == "Updated desc"
    end
  end

  describe "deactivate_operation/1" do
    test "sets is_active to false" do
      {:ok, op} = Operations.create_operation(%{name: "ToDeactivate", created_by: "admin"})
      assert {:ok, deactivated} = Operations.deactivate_operation(op.id)
      assert deactivated.is_active == false
    end
  end

  describe "delete_operation/1" do
    test "deletes an operation" do
      {:ok, op} = Operations.create_operation(%{name: "ToDelete", created_by: "admin"})
      assert {:ok, _} = Operations.delete_operation(op.id)
      assert {:error, :not_found} = Operations.get_operation(op.id)
    end
  end

  describe "user assignment" do
    test "assign and unassign user" do
      {:ok, op} = Operations.create_operation(%{name: "AssignOp", created_by: "admin"})

      assert {:ok, _} = Operations.assign_user(op.id, "analyst1", "admin")
      user_ops = Operations.get_user_operations("analyst1")
      assert length(user_ops) >= 1

      assert {:ok, _} = Operations.unassign_user(op.id, "analyst1")
    end

    test "unassign non-existent returns not_found" do
      {:ok, op} = Operations.create_operation(%{name: "UnassignOp", created_by: "admin"})
      assert {:error, :not_found} = Operations.unassign_user(op.id, "nonexistent")
    end
  end

  describe "set_primary_operation/2" do
    test "sets primary and clears others" do
      {:ok, op1} = Operations.create_operation(%{name: "Primary1", created_by: "admin"})
      {:ok, op2} = Operations.create_operation(%{name: "Primary2", created_by: "admin"})

      Operations.assign_user(op1.id, "analyst", "admin")
      Operations.assign_user(op2.id, "analyst", "admin")

      assert {:ok, _} = Operations.set_primary_operation("analyst", op1.id)
      assert {:ok, _} = Operations.set_primary_operation("analyst", op2.id)

      user_ops = Operations.get_user_operations("analyst")
      primary = Enum.find(user_ops, & &1.is_primary)
      assert primary.operation.id == op2.id
    end

    test "returns not_assigned for unassigned operation" do
      {:ok, op} = Operations.create_operation(%{name: "NotAssigned", created_by: "admin"})
      assert {:error, :not_assigned} = Operations.set_primary_operation("stranger", op.id)
    end
  end

  describe "get_active_operation/1" do
    test "returns nil when no active operation" do
      assert {:ok, nil} = Operations.get_active_operation("nobody")
    end

    test "returns active primary operation" do
      {:ok, op} = Operations.create_operation(%{name: "ActivePrimary", created_by: "admin"})
      Operations.assign_user(op.id, "analyst", "admin")
      Operations.set_primary_operation("analyst", op.id)

      assert {:ok, result} = Operations.get_active_operation("analyst")
      assert result != nil
      assert result.operation.id == op.id
    end
  end
end
