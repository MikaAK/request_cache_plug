absinthe_loaded? = RequestCache.Application.dependency_found?(:absinthe) and
                    RequestCache.Application.dependency_found?(:absinthe_plug)

if absinthe_loaded? do
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

        Util.verbose_log("[RequestCache.ResolverMiddleware] Enabling cache for resolution")

        resolution
      else
        Util.log_cache_disabled_message()

        %{
          resolution |
          state: :resolved,
          value: opts[:value],
        }
      end
    end
  end
end
