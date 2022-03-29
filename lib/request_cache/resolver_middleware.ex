if RequestCache.Application.dependency_found?(:absinthe) and RequestCache.Application.dependency_found?(:absinthe_plug) do
  defmodule RequestCache.ResolverMiddleware do
    @moduledoc false

    alias RequestCache.Util

    @behaviour Absinthe.Middleware

    @type opts :: [ttl: pos_integer, cache: module, value: any]

    @impl Absinthe.Middleware
    def call(%Absinthe.Resolution{} = resolution, opts) do
      enable_cache_for_resolution(resolution, opts)
    end

    defp enable_cache_for_resolution(resolution, opts) do
      if resolution.context[RequestCache.Config.conn_private_key()][:enabled?] do
        config = [request: opts |> Util.merge_default_opts |> Keyword.delete(:value)]

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
        Util.raise_cache_disabled_exception()
      end
    end
  end
end
