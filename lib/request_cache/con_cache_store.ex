cond do
  RequestCache.Application.dependency_found?(:con_cache) ->
    defmodule RequestCache.ConCacheStore do
      @moduledoc false

      def start_link(opts \\ []) do
        opts = Keyword.merge(RequestCache.Config.default_concache_opts(), opts)

        ConCache.start_link(opts)
      end

      def child_spec(opts) do
        %{
          id: opts[:name] || :con_cache_request_plug_store,
          start: {RequestCache.ConCacheStore, :start_link, [opts]}
        }
      end

      def get(pid \\ nil, key) do
        {:ok, ConCache.get(
          pid || RequestCache.Config.default_concache_opts()[:name],
          key
        )}
      end

      def put(pid \\ nil, key, ttl, value) do
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
