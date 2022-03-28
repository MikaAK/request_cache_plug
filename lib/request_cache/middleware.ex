if RequestCache.Application.dependency_found?(:absinthe) do
  defmodule RequestCache.Middleware do
    @behaviour Absinthe.Middleware

    @impl Absinthe.Middleware
    def call(%Absinthe.Resolution{} = resolution, opts) do
      store_resolution(resolution, opts)
    end

    def store_resolution(resolution, opts) when is_list(opts) do
      enable_cache_for_resolution(resolution, opts)
    end

    def store_resolution(resolution, ttl) when is_integer(ttl) do
      enable_cache_for_resolution(resolution, ttl: ttl)
    end

    defp enable_cache_for_resolution(resolution, opts) do
      if resolution.context[RequestCache.Config.conn_private_key()][:enabled?] do
        config = [request: merge_default_opts(opts)]

        %{resolution |
          context: Map.put(resolution.context, RequestCache.Config.conn_private_key(), config)
        }
      else
        raise "RequestCache request enable attempted but hasn't been enabled by the plug, ensure query has a name and the RequestCache.Plug is part of your Endpoint"
      end
    end

    # TODO: These funcs are WET due to copy from Plug
    defp merge_default_opts(opts) do
      Keyword.merge([
        ttl: RequestCache.Config.default_ttl(),
        cache: RequestCache.Config.request_cache_module()
      ], opts)
    end
  end
end

