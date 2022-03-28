if RequestCache.Application.dependency_found?(:absinthe) and RequestCache.Application.dependency_found?(:absinthe_plug) do
  defmodule RequestCache.ResolverMiddleware do
    @behaviour Absinthe.Middleware

    @type opts :: [ttl: pos_integer, cache: module, value: any]

    @impl Absinthe.Middleware
    def call(%Absinthe.Resolution{} = resolution, opts) do
      enable_cache_for_resolution(resolution, opts)
    end

    defp enable_cache_for_resolution(resolution, opts) do
      if resolution.context[RequestCache.Config.conn_private_key()][:enabled?] do
        config = [request: opts |> merge_default_opts |> Keyword.delete(:value)]

        resolution = %{resolution |
          state: :resolved,
          value: opts[:value],
          context: Map.update!(
            resolution.context,
            RequestCache.Config.conn_private_key(),
            &Keyword.merge(&1, config)
          )
        }

        resolution
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

