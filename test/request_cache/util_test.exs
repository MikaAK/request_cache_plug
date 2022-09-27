defmodule RequestCache.UtilTest do
  use ExUnit.Case

  alias RequestCache.Util

  @moduletag :capture_log

  doctest Util

  test "module exists" do
    assert is_list(Util.module_info())
  end
end
