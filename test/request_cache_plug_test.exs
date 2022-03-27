defmodule RequestCachePlugTest do
  use ExUnit.Case
  doctest RequestCachePlug

  test "greets the world" do
    assert RequestCachePlug.hello() == :world
  end
end
