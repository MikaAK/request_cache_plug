defmodule RequestCache.TelemetryMetricsTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias RequestCache.Support.Utils

  @expected_ttl 3600000
  @expected_measurements %{count: 1}
  @expected_rest_cache_hit_event_name [:request_cache_plug, :rest, :cache_hit]
  @expected_rest_cache_miss_event_name [:request_cache_plug, :rest, :cache_miss]
  @expected_graphql_cache_hit_event_name [:request_cache_plug, :graphql, :cache_hit]
  @expected_graphql_cache_miss_event_name [:request_cache_plug, :graphql, :cache_miss]
  @expected_graphql_cache_put_event_name [:request_cache_plug, :graphql, :cache_put]
  @expected_cache_put_event_name [:request_cache_plug, :cache_put]

  @miss_cache_key "/graphql:BE1120D4C931B50910C1B8788FA21108"
  @hit_cache_key "/graphql:14BFE314D845C31342E288408A7DACE4"

  @expected_cache_miss_metadata %{ttl: @expected_ttl, cache_key: @miss_cache_key, labels: [:graphql, :test_endpoint]}
  @expected_cache_hit_metadata %{ttl: @expected_ttl, cache_key: @hit_cache_key, labels: [:graphql, :test_endpoint]}

  setup do: %{self: self()}

  describe "GraphQL RequestCache.Plug.call/2" do
    setup do
      conn = Map.put(Utils.graphql_conn(), :query_string, "?query=query any")

      %{conn: conn}
    end

    test "cache miss", %{self: self, test: test, conn: conn} do
      start_telemetry_listener(self, test, @expected_graphql_cache_miss_event_name)

      RequestCache.Plug.call(conn, %{})

      assert_receive {:telemetry_event, @expected_graphql_cache_miss_event_name,
                      @expected_measurements, _metadata}
    end

    test "cache miss with labels", %{self: self, test: test, conn: conn} do
      start_telemetry_listener(self, test, @expected_graphql_cache_miss_event_name)

      request = RequestCache.Util.merge_default_opts(labels: [:graphql, :test_endpoint])

      conn
      |> Plug.Conn.put_private(RequestCache.Config.conn_private_key(), request: request)
      |> RequestCache.Plug.call(%{})

      assert_receive {:telemetry_event, @expected_graphql_cache_miss_event_name,
                      @expected_measurements, @expected_cache_miss_metadata}
    end
  end

  describe "GraphQL RequestCache.Plug.call/2 cache hit" do

    setup do
      conn = Utils.graphql_conn()
      |> Map.put(:query_string, "?query=query all")

      RequestCache.ConCacheStore.put(
        nil,
        @hit_cache_key,
        1_000,
        "TEST_VALUE"
      )

      %{conn: conn}
    end

    test "cache hit", %{self: self, test: test, conn: conn} do
      start_telemetry_listener(self, test, @expected_graphql_cache_hit_event_name)

      RequestCache.Plug.call(conn, %{})

      assert_receive {:telemetry_event, @expected_graphql_cache_hit_event_name,
        @expected_measurements, _metadata}
    end

    test "cache hit with labels", %{self: self, test: test, conn: conn} do
      start_telemetry_listener(self, test, @expected_graphql_cache_hit_event_name)

      request = RequestCache.Util.merge_default_opts(labels: [:graphql, :test_endpoint])

      conn
      |> Plug.Conn.put_private(RequestCache.Config.conn_private_key(), request: request)
      |> RequestCache.Plug.call(%{})

      assert_receive {:telemetry_event, @expected_graphql_cache_hit_event_name,
        @expected_measurements, @expected_cache_hit_metadata}
    end
  end

  describe "REST RequestCache.Plug.call/2" do
    test "cache miss", %{self: self, test: test} do
      start_telemetry_listener(self, test, @expected_rest_cache_miss_event_name)

      Utils.rest_conn()
      |> Map.put(:query_string, "?page=1")
      |> RequestCache.Plug.call(%{})

      assert_receive {:telemetry_event, @expected_rest_cache_miss_event_name,
                      @expected_measurements, _metadata}
    end

    test "cache hit", %{self: self, test: test} do
      RequestCache.ConCacheStore.put(
        nil,
        "/entity:17CE1C08EA497571A3B6BEB378C320B1",
        10_000,
        "TEST_VALUE"
      )

      start_telemetry_listener(self, test, @expected_rest_cache_hit_event_name)

      Utils.rest_conn()
      |> Map.put(:query_string, "?page=2")
      |> RequestCache.Plug.call(%{})

      assert_receive {:telemetry_event, @expected_rest_cache_hit_event_name,
                      @expected_measurements, _metadata}
    end
  end

  describe "metrics/0" do
    test "metric definitions are correct" do
      assert [
               %Telemetry.Metrics.Counter{
                 description: "Cache hits on GraphQL endpoints",
                 event_name: @expected_graphql_cache_hit_event_name,
                 measurement: :count,
                 name: @expected_graphql_cache_hit_event_name ++ [:total]
               },
               %Telemetry.Metrics.Counter{
                 description: "Cache misses on GraphQL endpoints",
                 event_name: @expected_graphql_cache_miss_event_name,
                 measurement: :count,
                 name: @expected_graphql_cache_miss_event_name ++ [:total]
               },
               %Telemetry.Metrics.Counter{
                 description: "Cache hits on REST endpoints",
                 event_name: @expected_rest_cache_hit_event_name,
                 measurement: :count,
                 name: @expected_rest_cache_hit_event_name ++ [:total]
               },
               %Telemetry.Metrics.Counter{
                 description: "Cache misses on REST endpoints",
                 event_name: @expected_rest_cache_miss_event_name,
                 measurement: :count,
                 name: @expected_rest_cache_miss_event_name ++ [:total]
               },
               %Telemetry.Metrics.Counter{
                 description: "Cache puts",
                 event_name: @expected_cache_put_event_name,
                 measurement: :count,
                 name: @expected_cache_put_event_name ++ [:total]
               }
             ] = RequestCache.Metrics.metrics()
    end
  end

  defp start_telemetry_listener(self, handler_id, event_name, config \\ %{}) do
    :telemetry.attach(
      handler_id,
      event_name,
      event_handler(self),
      config
    )
  end

  defp event_handler(self) do
    fn name, measurements, metadata, _config ->
      send(self, {:telemetry_event, name, measurements, metadata})
    end
  end
end
