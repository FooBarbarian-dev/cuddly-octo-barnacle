defmodule Clio.Relations.CacheTest do
  use ExUnit.Case, async: false

  alias Clio.Relations.Cache

  setup do
    # Start the Cache GenServer for testing
    start_supervised!(Cache)
    Cache.clear()
    :ok
  end

  describe "put/3 and get/1" do
    test "stores and retrieves a value" do
      :ok = Cache.put(:key1, "value1")
      assert {:ok, "value1"} = Cache.get(:key1)
    end

    test "stores complex values" do
      data = %{tags: ["mimikatz", "recon"], count: 42}
      :ok = Cache.put(:complex, data)
      assert {:ok, ^data} = Cache.get(:complex)
    end

    test "returns :miss for unknown keys" do
      assert :miss = Cache.get(:nonexistent)
    end

    test "returns :miss for expired entries" do
      :ok = Cache.put(:ephemeral, "value", 1)
      Process.sleep(5)
      assert :miss = Cache.get(:ephemeral)
    end

    test "overwrites existing keys" do
      :ok = Cache.put(:key, "v1")
      :ok = Cache.put(:key, "v2")
      assert {:ok, "v2"} = Cache.get(:key)
    end
  end

  describe "invalidate/1" do
    test "removes a specific key" do
      :ok = Cache.put(:to_remove, "value")
      :ok = Cache.invalidate(:to_remove)
      assert :miss = Cache.get(:to_remove)
    end

    test "does not error on missing key" do
      assert :ok = Cache.invalidate(:nonexistent)
    end
  end

  describe "clear/0" do
    test "removes all entries" do
      :ok = Cache.put(:a, 1)
      :ok = Cache.put(:b, 2)
      :ok = Cache.clear()
      assert :miss = Cache.get(:a)
      assert :miss = Cache.get(:b)
    end
  end
end
