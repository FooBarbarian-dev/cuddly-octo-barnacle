defmodule Clio.AuthTest do
  use ExUnit.Case, async: true

  alias Clio.Auth

  describe "validate_username_format/1" do
    test "accepts valid usernames" do
      assert :ok = Auth.validate_username_format("admin")
      assert :ok = Auth.validate_username_format("john_doe")
      assert :ok = Auth.validate_username_format("user-123")
      assert :ok = Auth.validate_username_format("Analyst01")
    end

    test "rejects usernames starting with non-alpha" do
      assert {:error, :invalid_username_format} = Auth.validate_username_format("1admin")
      assert {:error, :invalid_username_format} = Auth.validate_username_format("_admin")
      assert {:error, :invalid_username_format} = Auth.validate_username_format("-admin")
    end

    test "rejects too short usernames" do
      assert {:error, :invalid_username_format} = Auth.validate_username_format("ab")
      assert {:error, :invalid_username_format} = Auth.validate_username_format("a")
    end

    test "rejects too long usernames" do
      long_name = "a" <> String.duplicate("b", 50)
      assert {:error, :invalid_username_format} = Auth.validate_username_format(long_name)
    end

    test "rejects usernames with special characters" do
      assert {:error, :invalid_username_format} = Auth.validate_username_format("admin@domain")
      assert {:error, :invalid_username_format} = Auth.validate_username_format("user name")
      assert {:error, :invalid_username_format} = Auth.validate_username_format("admin$root")
    end
  end

  describe "validate_password_policy/1" do
    test "accepts valid passwords" do
      assert :ok = Auth.validate_password_policy("SecureP@ss123!")
      assert :ok = Auth.validate_password_policy("MyStr0ng!Pass_")
    end

    test "rejects passwords shorter than 12 characters" do
      {:error, {:invalid_password, errors}} = Auth.validate_password_policy("Short1!aA")
      assert "must be at least 12 characters" in errors
    end

    test "rejects passwords longer than 128 characters" do
      long_pass = String.duplicate("Aa1!", 33)
      {:error, {:invalid_password, errors}} = Auth.validate_password_policy(long_pass)
      assert "must be at most 128 characters" in errors
    end

    test "requires uppercase letter" do
      {:error, {:invalid_password, errors}} = Auth.validate_password_policy("lowercase123!@#")
      assert "must contain an uppercase letter" in errors
    end

    test "requires lowercase letter" do
      {:error, {:invalid_password, errors}} = Auth.validate_password_policy("UPPERCASE123!@#")
      assert "must contain a lowercase letter" in errors
    end

    test "requires digit" do
      {:error, {:invalid_password, errors}} = Auth.validate_password_policy("NoDigitsHere!@#$")
      assert "must contain a digit" in errors
    end

    test "requires special character" do
      {:error, {:invalid_password, errors}} = Auth.validate_password_policy("NoSpecial1234Aa")
      assert "must contain a special character" in errors
    end

    test "rejects 3+ repeated characters" do
      {:error, {:invalid_password, errors}} = Auth.validate_password_policy("Passsword1234!@")
      assert "cannot contain 3+ repeated characters" in errors
    end

    test "rejects only letters followed by numbers" do
      {:error, {:invalid_password, errors}} = Auth.validate_password_policy("Abcdefghijk1234")
      assert "cannot be only letters followed by numbers" in errors
    end

    test "rejects SQL injection patterns" do
      {:error, {:invalid_password, errors}} = Auth.validate_password_policy("Aa1!SELECT * FROM")
      assert "cannot contain SQL injection patterns" in errors
    end

    test "rejects XSS patterns" do
      {:error, {:invalid_password, errors}} = Auth.validate_password_policy("Aa1!<script>alert")
      assert "cannot contain XSS patterns" in errors
    end

    test "returns multiple errors at once" do
      {:error, {:invalid_password, errors}} = Auth.validate_password_policy("short")
      assert length(errors) > 1
    end
  end

  describe "hash_password/1 and verify_password/2" do
    test "correctly hashes and verifies a password" do
      password = "TestPassword123!"
      hash = Auth.hash_password(password)

      assert is_binary(hash)
      assert Auth.verify_password(password, hash)
    end

    test "rejects wrong password" do
      hash = Auth.hash_password("CorrectPassword123!")
      refute Auth.verify_password("WrongPassword123!", hash)
    end

    test "generates different hashes for same password (random salt)" do
      password = "TestPassword123!"
      hash1 = Auth.hash_password(password)
      hash2 = Auth.hash_password(password)

      assert hash1 != hash2
      assert Auth.verify_password(password, hash1)
      assert Auth.verify_password(password, hash2)
    end
  end

  describe "compute_admin_proof/1" do
    setup do
      # Ensure admin_secret is set for tests
      Application.put_env(:clio, :admin_secret, "test_admin_secret_key")
      on_exit(fn -> Application.delete_env(:clio, :admin_secret) end)
      :ok
    end

    test "returns a hex string" do
      proof = Auth.compute_admin_proof("admin")
      assert is_binary(proof)
      assert proof =~ ~r/^[a-f0-9]+$/
    end

    test "is deterministic for same username" do
      assert Auth.compute_admin_proof("admin") == Auth.compute_admin_proof("admin")
    end

    test "differs for different usernames" do
      assert Auth.compute_admin_proof("admin") != Auth.compute_admin_proof("operator")
    end
  end

  describe "verify_admin/1" do
    setup do
      Application.put_env(:clio, :admin_secret, "test_admin_secret_key")
      on_exit(fn -> Application.delete_env(:clio, :admin_secret) end)
      :ok
    end

    test "verifies valid admin proof" do
      proof = Auth.compute_admin_proof("admin")
      user = %{role: :admin, admin_proof: proof, username: "admin"}
      assert :ok = Auth.verify_admin(user)
    end

    test "rejects invalid admin proof" do
      user = %{role: :admin, admin_proof: "invalid_proof", username: "admin"}
      assert {:error, :invalid_admin_proof} = Auth.verify_admin(user)
    end

    test "rejects non-admin users" do
      assert {:error, :not_admin} = Auth.verify_admin(%{role: :user})
      assert {:error, :not_admin} = Auth.verify_admin(%{})
    end
  end

  describe "should_refresh?/1" do
    test "returns false when token is young" do
      now = System.system_time(:second)
      claims = %{"iat" => now - 100, "exp" => now + 28_700}  # 100s elapsed out of 28800s
      refute Auth.should_refresh?(claims)
    end

    test "returns true when token is past 75% lifetime" do
      now = System.system_time(:second)
      lifetime = 28_800  # 8 hours
      claims = %{"iat" => now - (lifetime * 0.8 |> round()), "exp" => now + (lifetime * 0.2 |> round())}
      assert Auth.should_refresh?(claims)
    end
  end
end
