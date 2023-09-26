absinthe_loaded? = RequestCache.Application.dependency_found?(:absinthe) and
                    RequestCache.Application.dependency_found?(:absinthe_plug)
if absinthe_loaded? do
  defmodule RequestCache.Middleware do
    alias RequestCache.Util

    @behaviour Absinthe.Middleware

    @impl Absinthe.Middleware
    def call(%Absinthe.Resolution{} = resolution, opts) when is_list(opts) do
      opts = ensure_valid_ttl(opts)

      enable_cache_for_resolution(resolution, opts)
    end

    @impl Absinthe.Middleware
    def call(%Absinthe.Resolution{} = resolution, ttl) when is_integer(ttl) do
      enable_cache_for_resolution(resolution, ttl: ttl)
    end

    defp ensure_valid_ttl(opts) do
      ttl = opts[:ttl] || RequestCache.Config.default_ttl()

      Keyword.put(opts, :ttl, ttl)
    end

    defp enable_cache_for_resolution(%Absinthe.Resolution{} = resolution, opts) do
      resolution = resolve_resolver_func_middleware(resolution, opts)

      if resolution.context[RequestCache.Config.conn_private_key()][:enabled?] do
        Util.verbose_log("[RequestCache.Middleware] Enabling cache for resolution")

        root_resolution_path_item = List.last(resolution.path)

        cache_request? = !!root_resolution_path_item &&
                         root_resolution_path_item.schema_node.name === "RootQueryType" &&
                         query_name_whitelisted?(root_resolution_path_item.name, opts)

        %{resolution |
          value: resolution.value || opts[:value],
          context: Map.update!(
            resolution.context,
            RequestCache.Config.conn_private_key(),
            &Util.deep_merge(&1,
              request: opts,
              cache_request?: cache_request?
            )
          )
        }
      else
        Util.log_cache_disabled_message()

        resolution
      end
    end

    defp resolve_resolver_func_middleware(resolution, opts) do
      if resolver_middleware?(opts) do
        %{resolution | state: :resolved}
      else
        resolution
      end
    end

    defp resolver_middleware?(opts), do: opts[:value]

    defp query_name_whitelisted?(query_name, opts) do
      is_nil(opts[:whitelisted_query_names]) or query_name in opts[:whitelisted_query_names]
    end

    @spec store_result(
      result :: any,
      opts_or_ttl :: RequestCache.opts | pos_integer
    ) :: {:middleware, module, RequestCache.opts}
    def store_result(result, ttl) when is_integer(ttl) do
      store_result(result, [ttl: ttl])
    end

    def store_result(result, opts) when is_list(opts) do
      {:middleware, RequestCache.Middleware, Keyword.put(opts, :value, result)}
    end
  end
end
