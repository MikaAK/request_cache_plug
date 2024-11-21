cond do
  RequestCache.Application.dependency_found?(:con_cache) ->
    defmodule RequestCache.ConCacheStore do
      @moduledoc false
      @default_name RequestCache.Config.default_concache_opts()[:name]

      def start_link(opts \\ []) do
        opts = RequestCache.Config.default_concache_opts()
          |> Keyword.merge(opts)
          |> Keyword.put_new(:global_ttl, :timer.hours(1))

        ConCache.start_link(opts)
      end

      def child_spec(opts) do
        %{
          id: opts[:name] || @default_name,
          start: {RequestCache.ConCacheStore, :start_link, [opts]}
        }
      end

      def get(pid \\ @default_name, key) do
        {:ok, ConCache.get(
          pid || RequestCache.Config.default_concache_opts()[:name],
          key
        )}
      end

      def put(pid \\ @default_name, key, ttl, value) do
        ConCache.put(
          pid || RequestCache.Config.default_concache_opts()[:name],
          key,
          %ConCache.Item{value: value, ttl: ttl}
        )
      end
    end

  RequestCache.Config.request_cache_module() === RequestCache.ConCacheStore ->
    raise "Default cache is still set to RequestCache.ConCacheStore but ConCache isn't a dependency of this application\n\nEither configure a new :request_cache_module for :request_cache or add con_cache to your list of dependencies"

  true -> :another_module_used
end
