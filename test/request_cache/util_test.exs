defmodule RequestCache.UtilTest do
  @moduledoc false

  use ExUnit.Case, async: true

  describe "&deep_merge/2" do
    test "deep merges keywords with nested maps and keywords properly" do
      date_time_a = DateTime.utc_now()
      date_time_b = DateTime.add(DateTime.utc_now(), 100)

      assert [
        apple: %{
          a: 2,
          b: 3,
          c: 4,
          date: date_time_b
        },

        banana: [a: 1, b: 2],
      ] === RequestCache.Util.deep_merge(
        [apple: %{a: 1, b: 3, date: date_time_a}, banana: [a: 1]],
        [apple: %{a: 2, c: 4, date: date_time_b}, banana: [b: 2]]
      )
    end

    test "deep merges maps with nested keywords and maps properly" do
      date_time_a = DateTime.utc_now()
      date_time_b = DateTime.add(DateTime.utc_now(), 100)

      assert %{
        banana: %{a: 1, b: 2},
        apple: [
          b: 3,
          a: 2,
          c: 4,
          date: date_time_b
        ]
      } === RequestCache.Util.deep_merge(
        %{apple: [a: 1, b: 3, date: date_time_a], banana: %{a: 1}},
        %{apple: [a: 2, c: 4, date: date_time_b], banana: %{b: 2}}
      )
    end
  end
end
