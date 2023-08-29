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
        config = [request: Keyword.delete(opts, :value), cache_request?: true]

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

    @spec store_result(
      result :: any,
      opts_or_ttl :: opts | pos_integer
    ) :: {:middleware, module, RequestCache.ResolverMiddleware.opts}
    def store_result(result, ttl) when is_integer(ttl) do
      store_result(result, [ttl: ttl])
    end

    def store_result(result, opts) when is_list(opts) do
      {:middleware, RequestCache.ResolverMiddleware, Keyword.put(opts, :value, result)}
    end
  end
end
