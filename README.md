## RequestCache

[![Test](https://github.com/MikaAK/request_cache_plug/actions/workflows/test-actions.yml/badge.svg)](https://github.com/MikaAK/request_cache_plug/actions/workflows/test-actions.yml)
[![codecov](https://codecov.io/gh/MikaAK/request_cache_plug/branch/main/graph/badge.svg?token=RF4ASVG5PV)](https://codecov.io/gh/MikaAK/request_cache_plug)
[![Hex version badge](https://img.shields.io/hexpm/v/request_cache_plug.svg)](https://hex.pm/packages/request_cache_plug)

This plug allows us to cache our graphql queries and phoenix controller requests declaritevly

We call the cache inside either a resolver or a controller action and this will store it preventing further
executions of our query on repeat requests.

The goal of this plug is to short-circuit any processing phoenix would
normally do upon request including json decoding/parsing, the only step that should run is telemetry

### Installation

This  package can be installed by adding `request_cache_plug` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:request_cache_plug, "~> 0.2"}
  ]
end
```

Documentation can be found at <https://hexdocs.pm/request_cache_plug>.

### Config
This is the default config, it can all be changed
```elixir
config :request_cache_plug,
  enabled?: true,
  verbose?: false,
  graphql_paths: ["/graphiql", "/graphql"],
  conn_priv_key: :__shared_request_cache__,
  request_cache_module: RequestCache.ConCacheStore,
  default_ttl: :timer.hours(1),
  default_concache_opts: [
    ttl_check_interval: :timer.seconds(1),
    acquire_lock_timeout: :timer.seconds(1),
    ets_options: [write_concurrency: true, read_concurrency: true]
  ]
```

### Usage
This plug is intended to be inserted into the `endpoint.ex` fairly early in the pipeline,
it should go after telemetry but before our parsers

```elixir
plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

plug RequestCache.Plug

plug Plug.Parsers,
  parsers: [:urlencoded, :multipart, :json],
  pass: ["*/*"]
```

We also need to setup a before_send hook to our absinthe_plug (if not using absinthe you can skip this step)
```elixir
plug Absinthe.Plug, before_send: {RequestCache, :connect_absinthe_context_to_conn}
```
What this does is allow us to see the results of items we put onto our request context from within plugs coming after absinthe

After that we can utilize our cache in a few ways

#### Utilization with Phoenix Controllers
```elixir
def index(conn, params) do
  conn
    |> RequestCache.store(:timer.seconds(60))
    |> put_status(200)
    |> json(%{...})
end
```

#### Utilization with Absinthe Resolvers
```elixir
def all(params, _resolution) do
  # Instead of returning {:ok, value} we return this
  RequestCache.store(value, :timer.seconds(60))
end
```

#### Utilization with Absinthe Middleware
```elixir
field :user, :user do
  arg :id, non_null(:id)

  middleware RequestCache.Middleware, ttl: :timer.seconds(60)

  resolve &Resolvers.User.find/2
end
```

### Specifying Specific Caching Locations
We have a few ways to control the caching location of our RequestCache, by default if you have `con_cache` installed,
we have access to `RequestCache.ConCacheStore` which is the default setting
However we can override this by setting `config :request_cache_plug, :request_cache_module, MyCustomCache`

Caching module will be expected to have the following API:
```elixir
def get(key) do
  ...
end

def put(key, ttl, value) do
  ...
end
```

You are responsible for starting the cache, including ConCacheStore, so if you're planning to use it make sure
you add `RequestCache.ConCacheStore` to the application.ex list of children

***Specifying the module per function is currently not fully implemented, check back soon for updates***

We can also override the module for a particular request by passing the option to our graphql middleware or
our `&RequestCache.store/2` function as `[ttl: 123, cache: MyCacheModule]`

##### With Middleware

```elixir
field :user, :user do
  arg :id, non_null(:id)

  middleware RequestCache.Middleware, ttl: :timer.seconds(60), cache: MyCacheModule

  resolve &Resolvers.User.find/2
end
```

##### In a Resolver

```elixir
def all(params, resolution) do
  RequestCache.store(value, ttl: :timer.seconds(60), cache: MyCacheModule)
end
```

##### In a Controller

```elixir
def index(conn, params) do
  RequestCache.store(conn, ttl: :timer.seconds(60), cache: MyCacheModule)
end
```

### telemetry

Cache events are emitted via :telemetry. Events are:

- `[:request_cache_plug, :graphql, :cache_hit]`
- `[:request_cache_plug, :graphql, :cache_miss]`
- `[:request_cache_plug, :rest, :cache_hit]`
- `[:request_cache_plug, :rest, :cache_miss]`
- `[:request_cache_plug, :cache_put]`

For GraphQL endpoints it is possible to provide a list of atoms that will be passed through to the event metadata; e.g.:

##### With Middleware

```elixir
field :user, :user do
  arg :id, non_null(:id)

  middleware RequestCache.Middleware, ttl: :timer.seconds(60), cache: MyCacheModule, labels: [:service, :endpoint]

  resolve &Resolvers.User.find/2
end
```

##### In a Resolver

```elixir
def all(params, resolution) do
  RequestCache.store(value, ttl: :timer.seconds(60), cache: MyCacheModule, labels: [:service, :endpoint])
end
```

The events will look like this:

```elixir
{
  [:request_cache_plug, :graphql, :cache_hit],
  %{count: 1},
  %{ttl: 3600000, cache_key: "/graphql:NNNN", labels: [:service, :endpoint]}
}
```

### Notes/Gotchas
- In order for this caching to work, we cannot be using POST requests as specced out by GraphQL, not for queries at least, fortunately this doesn't actually matter since we can use any http method we want (there will be a limit to query size), in a production app you may be doing this already due to the caching you gain from CloudFlare
- Caches for gql are stored via the name parameter that comes back from the query (for now) so you must name your queries to get caching
- Absinthe and ConCache are optional dependencies, if you don't have them you won't have access to `RequestCache.Middleware` or `RequestCache.ConCacheStore`
- If no ConCache is found, you must set `config :request_cache_module` to something else

### Caching Header
When an item is served from the cache, we return a header `rc-cache-status` which has a value of `HIT`. Using this you can tell if the item was
served out of cache, without it the item was fetched

### Example Reduction
In the case of a large (16mb) payload running through absinthe, this plug cuts down response times from 400+ms -> <400μs


<img width="704" alt="image" src="https://user-images.githubusercontent.com/4650931/161464277-713e994b-1246-43ac-82a1-fb2442cd7bce.png">
