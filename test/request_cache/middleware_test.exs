defmodule RequestCache.MiddlewareTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  describe "&call/2" do
    test "stores request configuration inside the context under configured conn_priv_key" do
      resolution = %Absinthe.Resolution{
        context: %{RequestCache.Config.conn_private_key() => [enabled?: true]}
      }
      resolution = RequestCache.Middleware.call(resolution, ttl: :timer.seconds(10))

      request_config = resolution.context[RequestCache.Config.conn_private_key()][:request]

      assert request_config[:ttl] === :timer.seconds(10)
    end

    test "throws exception when hasn't been enabled" do
      resolution = %Absinthe.Resolution{}

      assert capture_log(fn ->
               RequestCache.Middleware.call(resolution, ttl: :timer.seconds(10))
             end) =~ "RequestCache requested"
    end

    test "default_ttl is applied when nil is given in map" do
      resolution = %Absinthe.Resolution{
        context: %{RequestCache.Config.conn_private_key() => [enabled?: true]}
      }
      resolution = RequestCache.Middleware.call(resolution, ttl: nil)
      request_config = resolution.context[RequestCache.Config.conn_private_key()][:request]
      assert request_config[:ttl] === RequestCache.Config.default_ttl()
    end
  end
end
