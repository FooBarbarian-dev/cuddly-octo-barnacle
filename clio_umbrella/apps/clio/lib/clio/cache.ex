defmodule Clio.Cache do
  @moduledoc """
  Cache wrapper using Cachex (ETS-backed) that transparently encrypts/decrypts
  all values using AES-256-GCM.
  """

  @cache_name :clio_auth_cache

  def child_spec(_opts) do
    %{
      id: __MODULE__,
      start: {Cachex, :start_link, [@cache_name, [limit: 10_000]]},
      type: :supervisor
    }
  end

  def get(key) do
    case Cachex.get(@cache_name, key) do
      {:ok, nil} -> {:ok, nil}
      {:ok, encrypted} -> {:ok, decrypt(encrypted)}
    end
  end

  def set(key, value) do
    case Cachex.put(@cache_name, key, encrypt(value)) do
      {:ok, true} -> {:ok, "OK"}
    end
  end

  def setex(key, ttl_seconds, value) do
    case Cachex.put(@cache_name, key, encrypt(value), ttl: :timer.seconds(ttl_seconds)) do
      {:ok, true} -> {:ok, "OK"}
    end
  end

  def del(key) do
    case Cachex.del(@cache_name, key) do
      {:ok, true} -> {:ok, 1}
    end
  end

  def exists?(key) do
    case Cachex.exists?(@cache_name, key) do
      {:ok, true} -> true
      _ -> false
    end
  end

  def sadd(key, member) do
    encrypted_member = encrypt(member)

    case Cachex.get(@cache_name, key) do
      {:ok, nil} ->
        Cachex.put(@cache_name, key, MapSet.new([encrypted_member]))
        {:ok, 1}

      {:ok, %MapSet{} = set} ->
        Cachex.put(@cache_name, key, MapSet.put(set, encrypted_member))
        {:ok, 1}
    end
  end

  def srem(key, member) do
    encrypted_member = encrypt(member)

    case Cachex.get(@cache_name, key) do
      {:ok, nil} ->
        {:ok, 0}

      {:ok, %MapSet{} = set} ->
        new_set = MapSet.delete(set, encrypted_member)
        Cachex.put(@cache_name, key, new_set)
        {:ok, 1}
    end
  end

  def smembers(key) do
    case Cachex.get(@cache_name, key) do
      {:ok, nil} -> {:ok, []}
      {:ok, %MapSet{} = set} -> {:ok, set |> MapSet.to_list() |> Enum.map(&decrypt/1)}
    end
  end

  def keys(pattern) do
    # Convert glob pattern to a regex
    regex_pattern =
      pattern
      |> String.replace("*", ".*")
      |> String.replace("?", ".")
      |> then(&Regex.compile!("^#{&1}$"))

    {:ok, stream} = Cachex.stream(@cache_name)

    matching =
      stream
      |> Stream.filter(fn entry ->
        key = elem(entry, 1)
        is_binary(key) and Regex.match?(regex_pattern, key)
      end)
      |> Stream.map(fn entry -> elem(entry, 1) end)
      |> Enum.to_list()

    {:ok, matching}
  end

  def ttl(key) do
    case Cachex.ttl(@cache_name, key) do
      {:ok, nil} -> {:ok, -1}
      {:ok, ms} -> {:ok, div(ms, 1000)}
    end
  end

  def expire(key, seconds) do
    case Cachex.expire(@cache_name, key, :timer.seconds(seconds)) do
      {:ok, true} -> {:ok, 1}
      _ -> {:ok, 0}
    end
  end

  # Encryption helpers using AES-256-GCM
  defp encryption_key do
    Application.get_env(:clio, :cache_encryption_key)
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
