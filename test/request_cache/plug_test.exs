defmodule RequestCache.PlugTest do
  @moduledoc false

  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  defmodule FailingCacheModule do
    def get(_cache_key) do
      {:error, %{reason: :timeout}}
    end
  end

  describe "call/2" do
    @expected_log_content "reason: :timeout"

    setup do
      config = [cache: FailingCacheModule]

      conn = Plug.Conn.put_private(
        %Plug.Conn{method: "GET"},
        RequestCache.Config.conn_private_key(),
        request: config
      )

      %{conn: conn}
    end

    test "it handles errors from the cache implementation on GraphQL endpoints", %{conn: conn} do
      conn = conn
        |> Map.put(:request_path, "/graphql")
        |> Map.put(:query_string, "?query=query MyQuery{myQuery{}}")

      error = capture_log(fn ->
        assert %Plug.Conn{} = RequestCache.Plug.call(conn, nil)
      end)

      assert error =~ @expected_log_content
    end

    test "it handles errors from the cache implementation on REST endpoints", %{conn: conn} do
      conn = conn
        |> Map.put(:request_path, "/my/object/1")
        |> Map.put(:query_string, "?page=1")

      error = capture_log(fn ->
        assert %Plug.Conn{} = RequestCache.Plug.call(conn, nil)
      end)

      assert error =~ @expected_log_content
    end
  end
end
