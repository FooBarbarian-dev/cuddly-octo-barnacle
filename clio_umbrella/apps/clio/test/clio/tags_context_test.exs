defmodule Clio.TagsContextTest do
  use Clio.DataCase, async: true

  alias Clio.Tags
  alias Clio.Tags.Tag
  alias Clio.Logs

  describe "create_tag/1" do
    test "creates a tag with valid attributes" do
      attrs = %{name: "mimikatz", category: "tool", color: "#FF0000"}
      assert {:ok, tag} = Tags.create_tag(attrs)
      assert tag.name == "mimikatz"
      assert tag.category == "tool"
      assert tag.color == "#FF0000"
    end

    test "normalizes name on create" do
      assert {:ok, tag} = Tags.create_tag(%{name: "  MIMIKATZ  "})
      assert tag.name == "mimikatz"
    end

    test "upserts on conflict" do
      attrs = %{name: "recon", category: "technique"}
      assert {:ok, tag1} = Tags.create_tag(attrs)
      assert {:ok, tag2} = Tags.create_tag(attrs)
      assert tag1.id == tag2.id
    end
  end

  describe "get_tag/1" do
    test "returns tag when found" do
      {:ok, created} = Tags.create_tag(%{name: "test_tag"})
      assert {:ok, tag} = Tags.get_tag(created.id)
      assert tag.name == "test_tag"
    end

    test "returns not_found when missing" do
      assert {:error, :not_found} = Tags.get_tag(999_999)
    end
  end

  describe "get_tag_by_name/1" do
    test "finds tag by name (case-insensitive)" do
      {:ok, _} = Tags.create_tag(%{name: "bloodhound"})
      assert {:ok, tag} = Tags.get_tag_by_name("bloodhound")
      assert tag.name == "bloodhound"
    end

    test "trims and lowercases search" do
      {:ok, _} = Tags.create_tag(%{name: "cobalt strike"})
      assert {:ok, _} = Tags.get_tag_by_name("  Cobalt Strike  ")
    end
  end

  describe "get_or_create/2" do
    test "creates new tag if not exists" do
      assert {:ok, tag} = Tags.get_or_create("new_tag", category: "tool")
      assert tag.name == "new_tag"
      assert tag.category == "tool"
    end

    test "returns existing tag if exists" do
      {:ok, original} = Tags.create_tag(%{name: "existing", category: "tool"})
      assert {:ok, found} = Tags.get_or_create("existing")
      assert found.id == original.id
    end
  end

  describe "update_tag/2" do
    test "updates a regular tag" do
      {:ok, tag} = Tags.create_tag(%{name: "old_name"})
      assert {:ok, updated} = Tags.update_tag(tag.id, %{color: "#FF5733"})
      assert updated.color == "#FF5733"
    end

    test "blocks updates to operation tags" do
      {:ok, tag} = Tags.create_tag(%{name: "op:test", category: "operation"})
      assert {:error, :operation_tag_protected} = Tags.update_tag(tag.id, %{color: "#000000"})
    end
  end

  describe "delete_tag/1" do
    test "deletes a regular tag" do
      {:ok, tag} = Tags.create_tag(%{name: "deleteme"})
      assert {:ok, _} = Tags.delete_tag(tag.id)
      assert {:error, :not_found} = Tags.get_tag(tag.id)
    end

    test "blocks deletion of operation tags" do
      {:ok, tag} = Tags.create_tag(%{name: "op:protected", category: "operation"})
      assert {:error, :operation_tag_protected} = Tags.delete_tag(tag.id)
    end
  end

  describe "list_tags/0" do
    test "returns all tags ordered by name" do
      {:ok, _} = Tags.create_tag(%{name: "zebra"})
      {:ok, _} = Tags.create_tag(%{name: "alpha"})
      tags = Tags.list_tags()
      names = Enum.map(tags, & &1.name)
      assert names == Enum.sort(names)
    end
  end

  describe "autocomplete/1" do
    test "finds tags matching search term" do
      {:ok, _} = Tags.create_tag(%{name: "mimikatz"})
      {:ok, _} = Tags.create_tag(%{name: "mimi_tool"})
      {:ok, _} = Tags.create_tag(%{name: "unrelated"})

      results = Tags.autocomplete("mimi")
      names = Enum.map(results, & &1.name)
      assert "mimikatz" in names
      assert "mimi_tool" in names
      refute "unrelated" in names
    end

    test "limits results to 20" do
      for i <- 1..25 do
        Tags.create_tag(%{name: "match_#{String.pad_leading(to_string(i), 3, "0")}"})
      end

      results = Tags.autocomplete("match")
      assert length(results) <= 20
    end
  end

  describe "tag_stats/0" do
    test "returns tags with usage counts" do
      {:ok, _} = Tags.create_tag(%{name: "stat_test"})
      stats = Tags.tag_stats()
      assert is_list(stats)
      assert Enum.all?(stats, fn s -> Map.has_key?(s, :tag) and Map.has_key?(s, :usage_count) end)
    end
  end

  describe "add_tag_to_log/3 and remove_tag_from_log/2" do
    test "adds and removes tag from log" do
      {:ok, log} = Logs.create_log(%{command: "test"}, %{username: "admin", role: :admin})
      {:ok, tag} = Tags.create_tag(%{name: "test_assoc"})

      assert {:ok, _} = Tags.add_tag_to_log(log.id, tag.id, "admin")

      # Verify tag is associated
      {:ok, reloaded} = Logs.get_log(log.id)
      assert Enum.any?(reloaded.tags, &(&1.id == tag.id))

      # Remove
      assert {:ok, _} = Tags.remove_tag_from_log(log.id, tag.id)
    end

    test "idempotent add (on_conflict: nothing)" do
      {:ok, log} = Logs.create_log(%{command: "test"}, %{username: "admin", role: :admin})
      {:ok, tag} = Tags.create_tag(%{name: "idempotent_test"})

      assert {:ok, _} = Tags.add_tag_to_log(log.id, tag.id, "admin")
      assert {:ok, _} = Tags.add_tag_to_log(log.id, tag.id, "admin")
    end
  end
end
