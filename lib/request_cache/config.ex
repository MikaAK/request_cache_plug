defmodule RequestCache.Config do
  @moduledoc false

  @app :request_cache_plug

  def verbose? do
    !!Application.get_env(@app, :verbose?, false)
  end

  def graphql_paths do
    Application.get_env(@app, :graphql_paths) || ["/graphiql", "/graphql"]
  end

  def conn_private_key do
    Application.get_env(@app, :conn_priv_key) || :__shared_request_cache__
  end

  def cached_errors do
    Application.get_env(@app, :cached_errors) || []
  end

  def request_cache_module do
    Application.get_env(@app, :request_cache_module) || RequestCache.ConCacheStore
  end

  def default_ttl do
    Application.get_env(@app, :default_ttl) || :timer.hours(1)
  end

  def enabled? do
    !!Application.get_env(@app, :enabled?, true)
  end

  def default_concache_opts do
    Application.get_env(@app, :default_concache_opts) || [
      name: :con_cache_request_cache_store,
      global_ttl: default_ttl(),
      acquire_lock_timeout: :timer.seconds(1),
      ttl_check_interval: :timer.seconds(1),
      ets_options: [write_concurrency: true, read_concurrency: true]
    ]
  end
end
