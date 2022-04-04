if RequestCache.Application.dependency_found?(:absinthe) and RequestCache.Application.dependency_found?(:absinthe_plug) do
  defmodule RequestCache.Middleware do
    alias RequestCache.Util

    @behaviour Absinthe.Middleware

    @impl Absinthe.Middleware
    def call(%Absinthe.Resolution{} = resolution, opts) when is_list(opts) do
      enable_cache_for_resolution(resolution, opts)
    end

    @impl Absinthe.Middleware
    def call(%Absinthe.Resolution{} = resolution, ttl) when is_integer(ttl) do
      enable_cache_for_resolution(resolution, ttl: ttl)
    end

    defp enable_cache_for_resolution(resolution, opts) do
      if resolution.context[RequestCache.Config.conn_private_key()][:enabled?] do
        %{resolution |
          context: Map.update!(
            resolution.context,
            RequestCache.Config.conn_private_key(),
            &Keyword.put(&1, :request, Util.merge_default_opts(opts))
          )
        }
      else
        Util.log_cache_disabled_message()

        resolution
      end
    end
  end
end

