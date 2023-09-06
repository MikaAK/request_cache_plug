defmodule RequestCache.ConCacheStoreTest do
  use ExUnit.Case, async: true

  alias RequestCache.ConCacheStore

  describe "&get/1 and &put/3" do
    setup do
      key = "key_#{Enum.random(1..100_000_000_000)}"
      value = %{test: "key_#{Enum.random(1..100_000_000_000)}_key"}
      {:ok, pid} = ConCacheStore.start_link(name: :"#{key}_cache", ttl_check_interval: 10)

      %{
        key: key,
        value: value,
        pid: pid
      }
    end

    test "can put into cache and pull items out", %{pid: pid, key: key, value: value} do
      assert {:ok, nil} = ConCacheStore.get(pid, key)

      assert :ok = ConCacheStore.put(pid, key, :timer.seconds(100), value)

      assert {:ok, ^value} = ConCacheStore.get(pid, key)
    end

    test "items expire via ttl", %{pid: pid, key: key, value: value} do
      assert {:ok, nil} = ConCacheStore.get(pid, key)

      assert :ok = ConCacheStore.put(pid, key, 25, value)

      Process.sleep(50)

      assert {:ok, nil} = ConCacheStore.get(pid, key)
    end
  end

  describe "&child_spec/1" do
    test "starts up properly" do
      pid_name = :"test_#{Enum.random(1..100_000_000)}"

      start_link_supervised!(RequestCache.ConCacheStore.child_spec(name: pid_name))

      assert pid_name |> Process.whereis |> Process.alive?
    end
  end
end
