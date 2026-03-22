defmodule Clio.SanitizerTest do
  use ExUnit.Case, async: true

  alias Clio.Sanitizer

  describe "sanitize_value/1" do
    test "strips HTML tags from strings" do
      assert Sanitizer.sanitize_value("<script>alert('xss')</script>hello") =~ "hello"
      refute Sanitizer.sanitize_value("<script>alert('xss')</script>") =~ "<script>"
    end

    test "passes through non-string values" do
      assert Sanitizer.sanitize_value(42) == 42
      assert Sanitizer.sanitize_value(true) == true
      assert Sanitizer.sanitize_value(nil) == nil
    end

    test "sanitizes nested lists" do
      result = Sanitizer.sanitize_value(["<b>bold</b>", "<em>italic</em>"])
      assert is_list(result)
      refute Enum.any?(result, &String.contains?(&1, "<"))
    end

    test "sanitizes nested maps" do
      result = Sanitizer.sanitize_value(%{"key" => "<script>x</script>val"})
      refute String.contains?(result["key"], "<script>")
    end
  end

  describe "sanitize_field/2 for shell fields" do
    test "escapes < and > in command field" do
      result = Sanitizer.sanitize_field(:command, "echo <test> | grep foo")
      assert result == "echo &lt;test&gt; | grep foo"
    end

    test "escapes < and > in notes field" do
      result = Sanitizer.sanitize_field(:notes, "file <config.xml>")
      assert result =~ "&lt;"
      assert result =~ "&gt;"
    end

    test "preserves pipe, semicolon, etc in commands" do
      cmd = "cat /etc/passwd | grep root; whoami && id"
      result = Sanitizer.sanitize_field(:command, cmd)
      assert result == cmd
    end
  end

  describe "sanitize_field/2 for username" do
    test "strips disallowed characters" do
      assert Sanitizer.sanitize_field(:username, "admin$%^&") == "admin"
    end

    test "allows alphanumeric, underscore, hyphen, slash, backslash" do
      assert Sanitizer.sanitize_field(:username, "admin_user-1") == "admin_user-1"
    end
  end

  describe "validate_ip/1" do
    test "accepts valid IPv4" do
      assert Sanitizer.validate_ip("192.168.1.1") == "192.168.1.1"
      assert Sanitizer.validate_ip("10.0.0.1") == "10.0.0.1"
      assert Sanitizer.validate_ip("255.255.255.255") == "255.255.255.255"
    end

    test "accepts valid IPv6" do
      assert Sanitizer.validate_ip("::1") == "::1"
      assert Sanitizer.validate_ip("fe80::1") == "fe80::1"
    end

    test "rejects invalid IPs" do
      assert Sanitizer.validate_ip("not-an-ip") == nil
      assert Sanitizer.validate_ip("") == nil
      assert Sanitizer.validate_ip("999.999.999.999") == nil
    end
  end

  describe "normalize_mac/1" do
    test "normalizes colon-separated MAC" do
      assert Sanitizer.normalize_mac("aa:bb:cc:dd:ee:ff") == "AA-BB-CC-DD-EE-FF"
    end

    test "normalizes dot-separated MAC" do
      assert Sanitizer.normalize_mac("aa.bb.cc.dd.ee.ff") == "AA-BB-CC-DD-EE-FF"
    end

    test "normalizes already-dashed MAC" do
      assert Sanitizer.normalize_mac("aa-bb-cc-dd-ee-ff") == "AA-BB-CC-DD-EE-FF"
    end

    test "rejects invalid MACs" do
      assert Sanitizer.normalize_mac("not-a-mac") == nil
      assert Sanitizer.normalize_mac("ZZ:ZZ:ZZ:ZZ:ZZ:ZZ") == nil
    end
  end

  describe "sanitize_params/1" do
    test "sanitizes map params with known atom keys" do
      params = %{
        "command" => "echo <test>",
        "notes" => "<b>bold</b>",
        "hostname" => "<script>x</script>host"
      }
      result = Sanitizer.sanitize_params(params)
      # command should escape angle brackets (shell field)
      assert result["command"] =~ "&lt;"
      # hostname should strip HTML
      refute String.contains?(result["hostname"], "<script>")
    end

    test "handles IP fields" do
      params = %{"internal_ip" => "192.168.1.1", "external_ip" => "invalid"}
      result = Sanitizer.sanitize_params(params)
      assert result["internal_ip"] == "192.168.1.1"
      assert result["external_ip"] == nil
    end

    test "handles MAC field" do
      params = %{"mac_address" => "aa:bb:cc:dd:ee:ff"}
      result = Sanitizer.sanitize_params(params)
      assert result["mac_address"] == "AA-BB-CC-DD-EE-FF"
    end

    test "passes through non-map input" do
      assert Sanitizer.sanitize_params("string") == "string"
      assert Sanitizer.sanitize_params(42) == 42
    end
  end

  describe "validate_username/1" do
    test "strips invalid characters" do
      assert Sanitizer.validate_username("admin<script>") == "admin"
    end

    test "preserves valid username characters" do
      assert Sanitizer.validate_username("john_doe-1") == "john_doe-1"
    end
  end
end
