import Config

config :request_cache,
  graphql_paths: ["/graphiql", "/graphql"],
  conn_priv_key: :__shared_request_cache__,
  request_cache_module: RequestCache.ConCacheStore,
  default_ttl: :timer.hours(1),
  default_concache_opts: [
    aquire_lock_timeout: :timer.seconds(1),
    ets_options: [:write_concurrency, :read_concurrency]
  ]
