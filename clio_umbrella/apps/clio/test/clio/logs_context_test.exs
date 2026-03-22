defmodule Clio.LogsContextTest do
  use Clio.DataCase, async: true

  alias Clio.Logs
  alias Clio.Logs.Log

  @admin_user %{username: "admin", role: :admin}

  describe "create_log/2" do
    test "creates a log with valid attributes" do
      attrs = %{command: "whoami", hostname: "target01", username: "root"}
      assert {:ok, log} = Logs.create_log(attrs, @admin_user)
      assert log.command == "whoami"
      assert log.hostname == "target01"
      assert log.analyst == "admin"
      assert log.timestamp != nil
    end

    test "sets analyst from current user" do
      attrs = %{command: "id"}
      user = %{username: "analyst1", role: :user}
      assert {:ok, log} = Logs.create_log(attrs, user)
      assert log.analyst == "analyst1"
    end

    test "preloads tags and evidence files" do
      attrs = %{command: "ls -la"}
      assert {:ok, log} = Logs.create_log(attrs, @admin_user)
      assert log.tags == []
      assert log.evidence_files == []
    end
  end

  describe "get_log/1" do
    test "returns log with preloads when found" do
      {:ok, created} = Logs.create_log(%{command: "test"}, @admin_user)
      assert {:ok, log} = Logs.get_log(created.id)
      assert log.id == created.id
      assert is_list(log.tags)
    end

    test "returns not_found for missing logs" do
      assert {:error, :not_found} = Logs.get_log(999_999)
    end
  end

  describe "update_log/3" do
    test "updates an unlocked log" do
      {:ok, log} = Logs.create_log(%{command: "old"}, @admin_user)
      assert {:ok, updated} = Logs.update_log(log.id, %{command: "new"}, @admin_user)
      assert updated.command == "new"
    end

    test "returns preloaded associations after update" do
      {:ok, log} = Logs.create_log(%{command: "old"}, @admin_user)
      assert {:ok, updated} = Logs.update_log(log.id, %{command: "new"}, @admin_user)
      assert is_list(updated.tags)
      assert is_list(updated.evidence_files)
    end

    test "allows lock owner to update" do
      {:ok, log} = Logs.create_log(%{command: "test"}, @admin_user)
      {:ok, _} = Logs.lock_log(log.id, "admin")
      assert {:ok, _} = Logs.update_log(log.id, %{command: "updated"}, @admin_user)
    end

    test "blocks updates from non-lock-owner" do
      {:ok, log} = Logs.create_log(%{command: "test"}, @admin_user)
      {:ok, _} = Logs.lock_log(log.id, "other_user")
      user = %{username: "blocked_user", role: :user}
      assert {:error, :locked_by_another_user} = Logs.update_log(log.id, %{command: "x"}, user)
    end

    test "admins can update locked logs" do
      {:ok, log} = Logs.create_log(%{command: "test"}, @admin_user)
      {:ok, _} = Logs.lock_log(log.id, "other_user")
      assert {:ok, _} = Logs.update_log(log.id, %{command: "admin_update"}, @admin_user)
    end
  end

  describe "delete_log/2" do
    test "admin can delete a log" do
      {:ok, log} = Logs.create_log(%{command: "delete me"}, @admin_user)
      assert {:ok, _} = Logs.delete_log(log.id, @admin_user)
      assert {:error, :not_found} = Logs.get_log(log.id)
    end

    test "non-admin cannot delete" do
      user = %{username: "analyst", role: :user}
      assert {:error, :unauthorized} = Logs.delete_log(1, user)
    end
  end

  describe "lock_log/2 and unlock_log/2" do
    test "locks a log" do
      {:ok, log} = Logs.create_log(%{command: "test"}, @admin_user)
      assert {:ok, locked} = Logs.lock_log(log.id, "admin")
      assert locked.locked == true
      assert locked.locked_by == "admin"
    end

    test "returns error when locking already-locked log by another user" do
      {:ok, log} = Logs.create_log(%{command: "test"}, @admin_user)
      {:ok, _} = Logs.lock_log(log.id, "user1")
      assert {:error, :locked_by_another_user} = Logs.lock_log(log.id, "user2")
    end

    test "returns ok when re-locking own lock" do
      {:ok, log} = Logs.create_log(%{command: "test"}, @admin_user)
      {:ok, _} = Logs.lock_log(log.id, "user1")
      assert {:ok, _} = Logs.lock_log(log.id, "user1")
    end

    test "unlock by lock owner" do
      {:ok, log} = Logs.create_log(%{command: "test"}, @admin_user)
      {:ok, _} = Logs.lock_log(log.id, "admin")
      assert {:ok, unlocked} = Logs.unlock_log(log.id, @admin_user)
      assert unlocked.locked == false
      assert unlocked.locked_by == nil
    end

    test "admin can unlock anyone's lock" do
      {:ok, log} = Logs.create_log(%{command: "test"}, @admin_user)
      {:ok, _} = Logs.lock_log(log.id, "other_user")
      assert {:ok, _} = Logs.unlock_log(log.id, @admin_user)
    end

    test "non-owner non-admin cannot unlock" do
      {:ok, log} = Logs.create_log(%{command: "test"}, @admin_user)
      {:ok, _} = Logs.lock_log(log.id, "owner")
      user = %{username: "stranger", role: :user}
      assert {:error, :unauthorized} = Logs.unlock_log(log.id, user)
    end
  end

  describe "bulk_delete/2" do
    test "admin can bulk delete logs" do
      {:ok, log1} = Logs.create_log(%{command: "cmd1"}, @admin_user)
      {:ok, log2} = Logs.create_log(%{command: "cmd2"}, @admin_user)
      assert {:ok, 2} = Logs.bulk_delete([log1.id, log2.id], @admin_user)
    end

    test "non-admin cannot bulk delete" do
      user = %{username: "analyst", role: :user}
      assert {:error, :unauthorized} = Logs.bulk_delete([1, 2], user)
    end
  end

  describe "search_logs/2" do
    test "converts string params to keyword list options" do
      # This tests that the function at least runs without error
      # Full search requires operation setup
      params = %{
        "hostname" => "target",
        "command" => "whoami",
        "limit" => "10"
      }
      # Admin with no active operation sees all logs
      logs = Logs.search_logs(params, @admin_user)
      assert is_list(logs)
    end
  end

  describe "parse_datetime (via search_logs)" do
    test "handles date params without crashing" do
      params = %{
        "dateFrom" => "2024-01-01T00:00:00Z",
        "dateTo" => "2024-12-31T23:59:59Z"
      }
      logs = Logs.search_logs(params, @admin_user)
      assert is_list(logs)
    end

    test "handles invalid date params gracefully" do
      params = %{"dateFrom" => "not-a-date"}
      logs = Logs.search_logs(params, @admin_user)
      assert is_list(logs)
    end
  end
end
