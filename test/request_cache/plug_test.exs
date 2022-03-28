defmodule RequestCache.PlugTest do
  use ExUnit.Case, async: true

  describe "REST: &call/2" do
    test "enables ability to cache a request url in the controller"
    test "caches routes by url and params given to url"
    test "loads item into cache when no cache value found"
  end

  describe "GraphQL: &call/2" do
    test "enables ability to cache a request by query name in the resolver"
    test "caches routes by query name and variables"
    test "loads item into cache when no cache value found"
  end

  describe "General: &call/2" do
    test "caches data when &store_request/2 is called"
    test "caches data when request key found on absinthe context"
  end
end
