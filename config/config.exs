import Config

config :request_cache_plug,
  enabled?: true,
  verbose?: false,
  cached_errors: [],
  graphql_paths: ["/graphiql", "/graphql"],
  conn_priv_key: :__shared_request_cache__,
  request_cache_module: RequestCache.ConCacheStore,
  default_ttl: :timer.hours(1),
  default_concache_opts: [
    name: :con_cache_request_plug_store,
    global_ttl: :timer.hours(24 * 14),
    ttl_check_interval: :timer.seconds(1),
    acquire_lock_timeout: :timer.seconds(1),
    ets_options: [write_concurrency: true, read_concurrency: true]
  ]
