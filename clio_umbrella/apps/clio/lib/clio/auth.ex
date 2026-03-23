defmodule Clio.Auth do
  @moduledoc "Authentication context: login, password management, JWT, session verification."

  alias Clio.Cache

  @jwt_lifetime_seconds 8 * 60 * 60
  @refresh_threshold 0.75
  @pbkdf2_iterations 310_000
  @salt_bytes 32

  # ── Login ──

  def authenticate(username, password) do
    with :ok <- validate_username_format(username),
         :ok <- validate_password_format(password),
         {:ok, role} <- check_password(username, password) do
      requires_change = not has_custom_password?(username, role)
      admin_proof = if role == :admin, do: compute_admin_proof(username), else: nil

      user = %{
        id: random_hex(16),
        username: username,
        role: role,
        admin_proof: admin_proof,
        requires_password_change: requires_change
      }

      {:ok, user}
    end
  end

  defp check_password(username, password) do
    # Check custom password in cache first
    case Cache.get("admin:password:#{username}") do
      {:ok, hash} when not is_nil(hash) ->
        if verify_password(password, hash), do: {:ok, :admin}, else: {:error, :invalid_credentials}

      _ ->
        case Cache.get("user:password:#{username}") do
          {:ok, hash} when not is_nil(hash) ->
            if verify_password(password, hash), do: {:ok, :user}, else: {:error, :invalid_credentials}

          _ ->
            # Fall back to initial env passwords
            check_initial_passwords(password)
        end
    end
  end

  defp check_initial_passwords(password) do
    admin_pw = Application.get_env(:clio, :admin_password)
    user_pw = Application.get_env(:clio, :user_password)

    cond do
      admin_pw && timing_safe_compare(password, admin_pw) -> {:ok, :admin}
      user_pw && timing_safe_compare(password, user_pw) -> {:ok, :user}
      true -> {:error, :invalid_credentials}
    end
  end

  defp has_custom_password?(username, role) do
    prefix = if role == :admin, do: "admin", else: "user"
    Cache.exists?("#{prefix}:password:#{username}")
  end

  # ── Password Change ──

  def change_password(username, role, current_password, new_password) do
    with {:ok, _} <- authenticate(username, current_password),
         :ok <- validate_password_policy(new_password) do
      hash = hash_password(new_password)
      prefix = if role == :admin, do: "admin", else: "user"
      Cache.set("#{prefix}:password:#{username}", hash)
    end
  end

  def validate_password_policy(password) do
    validations = [
      {String.length(password) >= 12, "must be at least 12 characters"},
      {String.length(password) <= 128, "must be at most 128 characters"},
      {password =~ ~r/[A-Z]/, "must contain an uppercase letter"},
      {password =~ ~r/[a-z]/, "must contain a lowercase letter"},
      {password =~ ~r/[0-9]/, "must contain a digit"},
      {password =~ ~r/[^a-zA-Z0-9]/, "must contain a special character"},
      {not (password =~ ~r/(.)\1{2,}/), "cannot contain 3+ repeated characters"},
      {not (password =~ ~r/^[a-zA-Z]+[0-9]+$/), "cannot be only letters followed by numbers"},
      {not contains_sql_patterns?(password), "cannot contain SQL injection patterns"},
      {not contains_xss_patterns?(password), "cannot contain XSS patterns"}
    ]

    errors = for {false, msg} <- validations, do: msg

    case errors do
      [] -> :ok
      errs -> {:error, {:invalid_password, errs}}
    end
  end

  defp contains_sql_patterns?(password) do
    patterns = ~w(-- ; /* */ UNION SELECT DROP INSERT DELETE UPDATE ALTER EXEC EXECUTE)
    downcased = String.downcase(password)
    Enum.any?(patterns, fn p -> String.contains?(downcased, String.downcase(p)) end)
  end

  defp contains_xss_patterns?(password) do
    patterns = ["<script", "javascript:", "onerror=", "onload=", "onclick=", "onmouseover=", "onfocus=", "eval(", "expression("]
    downcased = String.downcase(password)
    Enum.any?(patterns, fn p -> String.contains?(downcased, String.downcase(p)) end)
  end

  # ── Password Hashing ──

  def hash_password(password) do
    salt = :crypto.strong_rand_bytes(@salt_bytes)
    derived_key = :crypto.pbkdf2_hmac(:sha256, password, salt, @pbkdf2_iterations, 32)
    Base.encode64(salt <> derived_key)
  end

  def verify_password(password, stored_hash) do
    decoded = Base.decode64!(stored_hash)
    <<salt::binary-size(@salt_bytes), expected_key::binary>> = decoded
    derived_key = :crypto.pbkdf2_hmac(:sha256, password, salt, @pbkdf2_iterations, 32)
    timing_safe_compare(derived_key, expected_key)
  end

  # ── JWT ──

  def issue_token(user) do
    jti = random_hex(16)
    server_instance_id = Application.get_env(:clio, :server_instance_id)
    now = System.system_time(:second)

    claims = %{
      "jti" => jti,
      "sub" => user.username,
      "role" => to_string(user.role),
      "server_instance_id" => server_instance_id,
      "iat" => now,
      "exp" => now + @jwt_lifetime_seconds
    }

    signer = Joken.Signer.create("HS256", jwt_secret())
    {:ok, token, _claims} = Joken.encode_and_sign(claims, signer)

    # Store in cache
    jwt_value = "username::#{user.username}::role::#{user.role}::issuedAt::#{now}"
    Cache.setex("jwt:#{jti}", @jwt_lifetime_seconds, jwt_value)
    Cache.sadd("user:#{user.username}:tokens", jti)

    {:ok, token, claims}
  end

  def verify_token(token) do
    signer = Joken.Signer.create("HS256", jwt_secret())

    with {:ok, claims} <- Joken.peek_claims(token),
         :ok <- verify_claims_structure(claims),
         :ok <- verify_expiration(claims),
         :ok <- verify_cache_exists(claims["jti"]),
         {:ok, verified_claims} <- Joken.verify(token, signer),
         :ok <- verify_server_instance(verified_claims) do
      user = %{
        username: verified_claims["sub"],
        role: String.to_existing_atom(verified_claims["role"]),
        jti: verified_claims["jti"],
        claims: verified_claims
      }

      {:ok, user}
    end
  end

  defp verify_claims_structure(claims) do
    required = ["jti", "exp", "iat"]
    if Enum.all?(required, &Map.has_key?(claims, &1)), do: :ok, else: {:error, :invalid_token_structure}
  end

  defp verify_expiration(claims) do
    if claims["exp"] > System.system_time(:second), do: :ok, else: {:error, :token_expired}
  end

  defp verify_cache_exists(jti) do
    if Cache.exists?("jwt:#{jti}"), do: :ok, else: {:error, :token_revoked}
  end

  defp verify_server_instance(claims) do
    server_id = Application.get_env(:clio, :server_instance_id)
    if claims["server_instance_id"] == server_id, do: :ok, else: {:error, :invalid_server_instance}
  end

  def should_refresh?(claims) do
    now = System.system_time(:second)
    lifetime = claims["exp"] - claims["iat"]
    elapsed = now - claims["iat"]
    elapsed >= lifetime * @refresh_threshold
  end

  def refresh_token(user, old_claims) do
    old_jti = old_claims["jti"]

    # Revoke old token
    Cache.del("jwt:#{old_jti}")
    Cache.srem("user:#{user.username}:tokens", old_jti)

    # Issue new one
    issue_token(user)
  end

  def revoke_token(jti, username) do
    Cache.del("jwt:#{jti}")
    Cache.srem("user:#{username}:tokens", jti)
    :ok
  end

  def revoke_all_user_tokens(username) do
    case Cache.smembers("user:#{username}:tokens") do
      {:ok, jtis} ->
        Enum.each(jtis, fn jti -> Cache.del("jwt:#{jti}") end)
        Cache.del("user:#{username}:tokens")
        :ok

      _ ->
        :ok
    end
  end

  # ── Admin Verification ──

  def verify_admin(%{role: :admin, admin_proof: proof, username: username}) do
    expected = compute_admin_proof(username)
    if timing_safe_compare(proof, expected), do: :ok, else: {:error, :invalid_admin_proof}
  end

  def verify_admin(_), do: {:error, :not_admin}

  def compute_admin_proof(username) do
    admin_secret = Application.get_env(:clio, :admin_secret)
    :crypto.mac(:hmac, :sha256, admin_secret, username) |> Base.encode16(case: :lower)
  end

  # ── Validation Helpers ──

  def validate_username_format(username) do
    if username =~ ~r/^[a-zA-Z][a-zA-Z0-9_-]{2,49}$/ do
      :ok
    else
      {:error, :invalid_username_format}
    end
  end

  defp validate_password_format(password) do
    cond do
      String.length(password) > 128 -> {:error, :password_too_long}
      contains_sql_patterns?(password) -> {:error, :invalid_password_format}
      contains_xss_patterns?(password) -> {:error, :invalid_password_format}
      true -> :ok
    end
  end

  # ── Helpers ──

  defp jwt_secret, do: Application.get_env(:clio, :jwt_secret)

  defp random_hex(bytes) do
    :crypto.strong_rand_bytes(bytes) |> Base.encode16(case: :lower)
  end

  defp timing_safe_compare(a, b) when is_binary(a) and is_binary(b) do
    byte_size(a) == byte_size(b) and :crypto.hash_equals(a, b)
  end

  defp timing_safe_compare(_, _), do: false
end
