defmodule RequestCachePlugTest do
  use ExUnit.Case, async: true

  test "stops any plug from running if cache is found"

  test "allows you to use &store/2 in a resolver to cache the results of the request"

  test "allows you to use &store/2 in a controller to cache the results of the request"

  test "throws an error if you try to call &store/2 in an non enabled controller"

  test "throws an error if you try to call &store/2 in an non enabled resolver"

  test "allows you to use `cache` key inside opts to override specific cache for a request"
end
