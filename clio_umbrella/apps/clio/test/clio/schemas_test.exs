defmodule Clio.SchemasTest do
  use Clio.DataCase, async: true

  alias Clio.Logs.Log
  alias Clio.Tags.Tag
  alias Clio.Tags.LogTag
  alias Clio.Operations.Operation
  alias Clio.Operations.UserOperation
  alias Clio.ApiKeys.ApiKey
  alias Clio.Evidence.EvidenceFile
  alias Clio.Templates.LogTemplate
  alias Clio.Relations.TagRelationship

  # ── Log Schema ──

  describe "Log.changeset/2" do
    test "valid changeset with minimal attrs" do
      changeset = Log.changeset(%Log{}, %{command: "whoami"})
      assert changeset.valid?
    end

    test "auto-sets timestamp when nil" do
      changeset = Log.changeset(%Log{}, %{command: "ls"})
      assert get_field(changeset, :timestamp) != nil
    end

    test "preserves provided timestamp" do
      ts = ~U[2024-01-15 10:30:00.000000Z]
      changeset = Log.changeset(%Log{}, %{timestamp: ts})
      assert get_field(changeset, :timestamp) == ts
    end

    test "validates command max length" do
      long_cmd = String.duplicate("a", 255)
      changeset = Log.changeset(%Log{}, %{command: long_cmd})
      assert %{command: ["should be at most 254 character(s)"]} = errors_on(changeset)
    end

    test "validates notes max length" do
      long_notes = String.duplicate("a", 255)
      changeset = Log.changeset(%Log{}, %{notes: long_notes})
      assert %{notes: ["should be at most 254 character(s)"]} = errors_on(changeset)
    end

    test "validates IP max length" do
      long_ip = String.duplicate("1", 46)
      changeset = Log.changeset(%Log{}, %{internal_ip: long_ip})
      assert %{internal_ip: _} = errors_on(changeset)
    end

    test "normalizes MAC address to uppercase with dashes" do
      changeset = Log.changeset(%Log{}, %{mac_address: "aa:bb:cc:dd:ee:ff"})
      assert get_change(changeset, :mac_address) == "AA-BB-CC-DD-EE-FF"
    end

    test "normalizes MAC address with dots" do
      changeset = Log.changeset(%Log{}, %{mac_address: "aa.bb.cc.dd.ee.ff"})
      assert get_change(changeset, :mac_address) == "AA-BB-CC-DD-EE-FF"
    end

    test "default locked is false" do
      changeset = Log.changeset(%Log{}, %{})
      assert get_field(changeset, :locked) == false
    end

    test "accepts all optional fields" do
      attrs = %{
        internal_ip: "192.168.1.1",
        external_ip: "8.8.8.8",
        mac_address: "AA-BB-CC-DD-EE-FF",
        hostname: "workstation01",
        domain: "corp.local",
        username: "admin",
        command: "whoami",
        notes: "test note",
        filename: "payload.exe",
        status: "active",
        hash_algorithm: "sha256",
        hash_value: "abc123",
        pid: "1234",
        analyst: "op1"
      }

      changeset = Log.changeset(%Log{}, attrs)
      assert changeset.valid?
    end
  end

  # ── Tag Schema ──

  describe "Tag.changeset/2" do
    test "valid changeset" do
      changeset = Tag.changeset(%Tag{}, %{name: "mimikatz", category: "tool"})
      assert changeset.valid?
    end

    test "requires name" do
      changeset = Tag.changeset(%Tag{}, %{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "normalizes name to lowercase trimmed" do
      changeset = Tag.changeset(%Tag{}, %{name: "  MIMIKATZ  "})
      assert get_change(changeset, :name) == "mimikatz"
    end

    test "validates category inclusion" do
      changeset = Tag.changeset(%Tag{}, %{name: "test", category: "invalid_category"})
      assert %{category: _} = errors_on(changeset)
    end

    test "accepts all valid categories" do
      categories = ~w(technique tool target status priority workflow evidence security operation custom)

      for cat <- categories do
        changeset = Tag.changeset(%Tag{}, %{name: "test_#{cat}", category: cat})
        assert changeset.valid?, "Category #{cat} should be valid"
      end
    end

    test "validates hex color format" do
      changeset = Tag.changeset(%Tag{}, %{name: "test", color: "not-a-color"})
      assert %{color: _} = errors_on(changeset)
    end

    test "accepts valid hex color" do
      changeset = Tag.changeset(%Tag{}, %{name: "test", color: "#FF5733"})
      assert changeset.valid?
    end

    test "validates name max length" do
      long_name = String.duplicate("a", 51)
      changeset = Tag.changeset(%Tag{}, %{name: long_name})
      assert %{name: _} = errors_on(changeset)
    end

    test "default color" do
      tag = %Tag{}
      assert tag.color == "#6B7280"
    end
  end

  describe "Tag.operation_tag?/1" do
    test "returns true for operation tags" do
      tag = %Tag{name: "op:thunderstrike", category: "operation"}
      assert Tag.operation_tag?(tag)
    end

    test "returns false for regular tags" do
      tag = %Tag{name: "mimikatz", category: "tool"}
      refute Tag.operation_tag?(tag)
    end

    test "returns false for op: prefix without operation category" do
      tag = %Tag{name: "op:test", category: "custom"}
      refute Tag.operation_tag?(tag)
    end
  end

  # ── LogTag Schema ──

  describe "LogTag.changeset/2" do
    test "requires log_id and tag_id" do
      changeset = LogTag.changeset(%LogTag{}, %{})
      errors = errors_on(changeset)
      assert %{log_id: _, tag_id: _} = errors
    end

    test "auto-sets tagged_at" do
      changeset = LogTag.changeset(%LogTag{}, %{log_id: 1, tag_id: 1, tagged_by: "analyst1"})
      assert get_field(changeset, :tagged_at) != nil
    end
  end

  # ── Operation Schema ──

  describe "Operation.changeset/2" do
    test "valid changeset" do
      changeset = Operation.changeset(%Operation{}, %{name: "Thunderstrike", created_by: "admin"})
      assert changeset.valid?
    end

    test "requires name and created_by" do
      changeset = Operation.changeset(%Operation{}, %{})
      errors = errors_on(changeset)
      assert %{name: _, created_by: _} = errors
    end

    test "validates name max length" do
      long_name = String.duplicate("a", 101)
      changeset = Operation.changeset(%Operation{}, %{name: long_name, created_by: "admin"})
      assert %{name: _} = errors_on(changeset)
    end

    test "default is_active is true" do
      op = %Operation{}
      assert op.is_active == true
    end
  end

  # ── UserOperation Schema ──

  describe "UserOperation.changeset/2" do
    test "requires username, operation_id, assigned_by" do
      changeset = UserOperation.changeset(%UserOperation{}, %{})
      errors = errors_on(changeset)
      assert %{username: _, operation_id: _, assigned_by: _} = errors
    end

    test "auto-sets assigned_at and last_accessed" do
      changeset = UserOperation.changeset(%UserOperation{}, %{
        username: "analyst1",
        operation_id: 1,
        assigned_by: "admin"
      })
      assert get_field(changeset, :assigned_at) != nil
      assert get_field(changeset, :last_accessed) != nil
    end
  end

  # ── ApiKey Schema ──

  describe "ApiKey.changeset/2" do
    test "valid changeset" do
      attrs = %{name: "Test Key", key_id: "abc123", key_hash: "def456", created_by: "admin"}
      changeset = ApiKey.changeset(%ApiKey{}, attrs)
      assert changeset.valid?
    end

    test "requires name, key_id, key_hash, created_by" do
      changeset = ApiKey.changeset(%ApiKey{}, %{})
      errors = errors_on(changeset)
      assert Map.has_key?(errors, :name)
      assert Map.has_key?(errors, :key_id)
      assert Map.has_key?(errors, :key_hash)
      assert Map.has_key?(errors, :created_by)
    end

    test "validates permissions contains only valid scopes" do
      attrs = %{
        name: "Test", key_id: "abc", key_hash: "def", created_by: "admin",
        permissions: ["logs:write", "invalid:scope"]
      }
      changeset = ApiKey.changeset(%ApiKey{}, attrs)
      assert %{permissions: _} = errors_on(changeset)
    end

    test "accepts valid permissions" do
      for perm <- ~w(logs:write logs:read logs:admin) do
        attrs = %{name: "Test", key_id: "abc", key_hash: "def", created_by: "admin", permissions: [perm]}
        changeset = ApiKey.changeset(%ApiKey{}, attrs)
        assert changeset.valid?, "Permission #{perm} should be valid"
      end
    end

    test "default permissions is logs:write" do
      key = %ApiKey{}
      assert key.permissions == ["logs:write"]
    end

    test "default is_active is true" do
      key = %ApiKey{}
      assert key.is_active == true
    end
  end

  # ── EvidenceFile Schema ──

  describe "EvidenceFile.changeset/2" do
    test "requires log_id, filename, original_filename, filepath" do
      changeset = EvidenceFile.changeset(%EvidenceFile{}, %{})
      errors = errors_on(changeset)
      assert Map.has_key?(errors, :log_id)
      assert Map.has_key?(errors, :filename)
      assert Map.has_key?(errors, :original_filename)
      assert Map.has_key?(errors, :filepath)
    end

    test "validates allowed mime types" do
      attrs = %{
        log_id: 1, filename: "test.exe", original_filename: "test.exe",
        filepath: "/tmp/test.exe", file_type: "application/x-msdownload"
      }
      changeset = EvidenceFile.changeset(%EvidenceFile{}, attrs)
      assert %{file_type: ["unsupported file type"]} = errors_on(changeset)
    end

    test "accepts valid mime types" do
      for mime <- EvidenceFile.allowed_mime_types() do
        attrs = %{
          log_id: 1, filename: "test", original_filename: "test",
          filepath: "/tmp/test", file_type: mime
        }
        changeset = EvidenceFile.changeset(%EvidenceFile{}, attrs)
        refute Map.has_key?(errors_on(changeset), :file_type), "MIME type #{mime} should be valid"
      end
    end

    test "validates 10MB file size limit" do
      attrs = %{
        log_id: 1, filename: "test", original_filename: "test",
        filepath: "/tmp/test", file_size: 10_485_761
      }
      changeset = EvidenceFile.changeset(%EvidenceFile{}, attrs)
      assert %{file_size: ["file exceeds 10MB limit"]} = errors_on(changeset)
    end

    test "auto-sets upload_date" do
      attrs = %{log_id: 1, filename: "test", original_filename: "test", filepath: "/tmp/test"}
      changeset = EvidenceFile.changeset(%EvidenceFile{}, attrs)
      assert get_field(changeset, :upload_date) != nil
    end
  end

  # ── LogTemplate Schema ──

  describe "LogTemplate.changeset/2" do
    test "valid changeset" do
      attrs = %{name: "Recon Template", template_data: %{"command" => "whoami"}, created_by: "admin"}
      changeset = LogTemplate.changeset(%LogTemplate{}, attrs)
      assert changeset.valid?
    end

    test "requires name, template_data, created_by" do
      changeset = LogTemplate.changeset(%LogTemplate{}, %{})
      errors = errors_on(changeset)
      assert Map.has_key?(errors, :name)
      assert Map.has_key?(errors, :template_data)
      assert Map.has_key?(errors, :created_by)
    end

    test "validates name max length" do
      attrs = %{name: String.duplicate("a", 101), template_data: %{}, created_by: "admin"}
      changeset = LogTemplate.changeset(%LogTemplate{}, attrs)
      assert %{name: _} = errors_on(changeset)
    end
  end

  # ── TagRelationship Schema ──

  describe "TagRelationship.changeset/2" do
    test "requires source_tag_id and target_tag_id" do
      changeset = TagRelationship.changeset(%TagRelationship{}, %{})
      errors = errors_on(changeset)
      assert Map.has_key?(errors, :source_tag_id)
      assert Map.has_key?(errors, :target_tag_id)
    end

    test "defaults" do
      tr = %TagRelationship{}
      assert tr.cooccurrence_count == 1
      assert tr.sequence_count == 0
      assert tr.correlation_strength == 0.0
    end
  end
end
