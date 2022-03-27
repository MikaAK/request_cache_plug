cond do
  Enum.any?(Application.loaded_applications(), fn {dep_name, _, _} -> dep_name === :con_cache end) ->
    defmodule RequestCache.ConCacheStore do
      def start_link(opts \\ []) do
        opts = Keyword.merge(RequestCache.Config.default_concache_opts(), opts)

        ConCache.start_link(opts)
      end

      def get(key) do
        ConCache.get(
          RequestCache.Config.default_concache_opts()[:name],
          key
        )
      end

      def put(key, ttl, value) do
        ConCache.put(
          RequestCache.Config.default_concache_opts()[:name],
          key,
          %ConCache.Item{value: value, ttl: ttl}
        )
      end
    end

  RequestCache.Config.request_cache_module() === RequestCache.ConCacheStore ->
    raise "Default cache is still set to RequestCache.ConCacheStore but ConCache isn't a dependency of this application\n\nEither configure a new :request_cache_module for :request_cache or add con_cache to your list of dependencies"
end
