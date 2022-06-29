defmodule RequestCache.Metrics do
  @moduledoc false

  import Telemetry.Metrics, only: [counter: 2]

  @app :request_cache_plug
  @graphql_cache_hit [@app, :graphql, :cache_hit]
  @graphql_cache_miss [@app, :graphql, :cache_miss]
  @rest_cache_hit [@app, :rest, :cache_hit]
  @rest_cache_miss [@app, :rest, :cache_miss]
  @cache_put [@app, :cache_put]

  @cache_count %{count: 1}

  @spec metrics() :: list(Counter.t())
  def metrics do
    [
      counter(
        counter_event_name(@graphql_cache_hit),
        event_name: @graphql_cache_hit,
        description: "Cache hits on GraphQL endpoints",
        measurement: :count,
        tags: [:labels]
      ),
      counter(
        counter_event_name(@graphql_cache_miss),
        event_name: @graphql_cache_miss,
        description: "Cache misses on GraphQL endpoints",
        measurement: :count,
        tags: [:labels]
      ),
      counter(
        counter_event_name(@rest_cache_hit),
        event_name: @rest_cache_hit,
        description: "Cache hits on REST endpoints",
        measurement: :count,
        tags: [:labels]
      ),
      counter(
        counter_event_name(@rest_cache_miss),
        event_name: @rest_cache_miss,
        description: "Cache misses on REST endpoints",
        measurement: :count,
        tags: [:labels]
      ),
      counter(
        counter_event_name(@cache_put),
        event_name: @cache_put,
        description: "Cache puts",
        measurement: :count,
        tags: [:labels]
      )
    ]
  end

  @spec inc_graphql_cache_hit(map()) :: :ok
  def inc_graphql_cache_hit(metadata), do: execute(@graphql_cache_hit, @cache_count, metadata)

  @spec inc_graphql_cache_miss(map()) :: :ok
  def inc_graphql_cache_miss(metadata), do: execute(@graphql_cache_miss, @cache_count, metadata)

  @spec inc_rest_cache_hit(map()) :: :ok
  def inc_rest_cache_hit(metadata), do: execute(@rest_cache_hit, @cache_count, metadata)

  @spec inc_rest_cache_miss(map()) :: :ok
  def inc_rest_cache_miss(metadata), do: execute(@rest_cache_miss, @cache_count, metadata)

  @spec inc_cache_put(map()) :: :ok
  def inc_cache_put(metadata), do: execute(@cache_put, @cache_count, metadata)

  @spec execute(keyword(), map(), map()) :: :ok
  def execute(event_name, measurements, metadata \\ %{}) do
    :telemetry.execute(
      event_name,
      measurements,
      metadata
    )
  end

  defp counter_event_name(event_name), do: "#{Enum.join(event_name, ".")}.total"
end
