defmodule Clio.Audit.WriterTest do
  use ExUnit.Case, async: true

  alias Clio.Audit.Writer

  describe "redact_sensitive_data/1" do
    test "redacts known sensitive keys" do
      data = %{
        "password" => "secret123",
        "token" => "jwt_abc",
        "key" => "api_key_xyz",
        "secrets" => "top_secret",
        "jwt_token" => "eyJ..."
      }

      result = Writer.redact_sensitive_data(data)

      assert result["password"] == "[REDACTED]"
      assert result["token"] == "[REDACTED]"
      assert result["key"] == "[REDACTED]"
      assert result["secrets"] == "[REDACTED]"
      assert result["jwt_token"] == "[REDACTED]"
    end

    test "preserves non-sensitive keys" do
      data = %{"username" => "admin", "action" => "login", "ip" => "1.2.3.4"}
      result = Writer.redact_sensitive_data(data)

      assert result["username"] == "admin"
      assert result["action"] == "login"
      assert result["ip"] == "1.2.3.4"
    end

    test "does not redact nil or empty sensitive values" do
      data = %{"password" => nil, "token" => ""}
      result = Writer.redact_sensitive_data(data)

      assert result["password"] == nil
      assert result["token"] == ""
    end

    test "recursively redacts nested maps" do
      data = %{
        "metadata" => %{
          "password" => "nested_secret",
          "detail" => "safe"
        }
      }

      result = Writer.redact_sensitive_data(data)
      assert result["metadata"]["password"] == "[REDACTED]"
      assert result["metadata"]["detail"] == "safe"
    end

    test "recursively redacts in lists" do
      data = %{
        "events" => [
          %{"token" => "abc123", "type" => "login"},
          %{"key" => "secret", "type" => "api_call"}
        ]
      }

      result = Writer.redact_sensitive_data(data)
      assert hd(result["events"])["token"] == "[REDACTED]"
      assert List.last(result["events"])["key"] == "[REDACTED]"
    end

    test "passes through non-map/list values" do
      assert Writer.redact_sensitive_data("string") == "string"
      assert Writer.redact_sensitive_data(42) == 42
      assert Writer.redact_sensitive_data(true) == true
      assert Writer.redact_sensitive_data(nil) == nil
    end
  end
end
