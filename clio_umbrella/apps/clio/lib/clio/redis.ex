defmodule Clio.Redis do
  @moduledoc """
  Redis wrapper that transparently encrypts/decrypts all values using AES-256-GCM.
  """

  alias Clio.Redis.Pool

  def get(key) do
    case Pool.command(["GET", key]) do
      {:ok, nil} -> {:ok, nil}
      {:ok, encrypted} -> {:ok, decrypt(encrypted)}
      {:error, _} = error -> error
    end
  end

  def set(key, value) do
    Pool.command(["SET", key, encrypt(value)])
  end

  def setex(key, ttl_seconds, value) do
    Pool.command(["SET", key, encrypt(value), "EX", ttl_seconds])
  end

  def del(key) do
    Pool.command(["DEL", key])
  end

  def exists?(key) do
    case Pool.command(["EXISTS", key]) do
      {:ok, 1} -> true
      _ -> false
    end
  end

  def sadd(key, member) do
    Pool.command(["SADD", key, encrypt(member)])
  end

  def srem(key, member) do
    Pool.command(["SREM", key, encrypt(member)])
  end

  def smembers(key) do
    case Pool.command(["SMEMBERS", key]) do
      {:ok, members} -> {:ok, Enum.map(members, &decrypt/1)}
      {:error, _} = error -> error
    end
  end

  def keys(pattern) do
    Pool.command(["KEYS", pattern])
  end

  def ttl(key) do
    Pool.command(["TTL", key])
  end

  def expire(key, seconds) do
    Pool.command(["EXPIRE", key, seconds])
  end

  def scan(cursor, opts \\ []) do
    args = ["SCAN", cursor]
    args = case Keyword.get(opts, :match) do
      nil -> args
      pattern -> args ++ ["MATCH", pattern]
    end
    args = case Keyword.get(opts, :count) do
      nil -> args
      count -> args ++ ["COUNT", count]
    end
    Pool.command(args)
  end

  # Encryption helpers using AES-256-GCM
  defp encryption_key do
    Application.get_env(:clio, :redis_encryption_key)
    |> Base.decode16!(case: :mixed)
    |> binary_part(0, 32)
  end

  defp encrypt(value) when is_binary(value) do
    key = encryption_key()
    iv = :crypto.strong_rand_bytes(12)
    {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, value, "", true)
    Base.encode64(iv <> tag <> ciphertext)
  end

  defp decrypt(encrypted) when is_binary(encrypted) do
    key = encryption_key()
    data = Base.decode64!(encrypted)
    <<iv::binary-12, tag::binary-16, ciphertext::binary>> = data
    :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, ciphertext, "", tag, false)
  end
end
