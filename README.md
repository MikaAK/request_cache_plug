## RequestCache

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
    {:request_cache_plug, "~> 0.1.0"}
  ]
end
```

Documentation can be found at <https://hexdocs.pm/request_cache_plug>.

### Config
```elixir
config :request_cache,
  graphql_paths: ["/graphql", "graphiql"] # Default
  cache_module: MyRequestCache
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

After that we can utilize our cache in a few ways

#### Utilization with Phoenix Controllers
```elixir
def index(conn, params) do
  RequestCache.store(conn, :timer.seconds(60))

  ...
end
```

#### Utilization with Absinthe Resolvers
```elixir
def all(params, resolution) do
  RequestCache.store(resolution, :timer.seconds(60))

  ...
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
However we can override this by setting `config :request_cache, :request_cache_module, MyCustomCache`

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

We can also override the module for a particular request by passing the option to our graphql middleware or
our `&RequestCache.store/2` function as `[ttl: 123, cache: MyCacheModule]`

```elixir
field :user, :user do
  arg :id, non_null(:id)

  middleware RequestCache.Middleware, ttl: :timer.seconds(60), cache: MyCacheModule

  resolve &Resolvers.User.find/2
end
```

or

```elixir
def all(params, resolution) do
  RequestCache.store(resolution, ttl: :timer.seconds(60), cache: MyCacheModule)

  ...
end
```

### Notes/Gotchas
- In order for this caching to work, we cannot be using POST requests as specced out by GraphQL, not for queries at least, fortunately this doesn't actually matter since we can use any http method we want (there will be a limit to query size), in a production app you may be doing this already due to the caching you gain from CloudFlare
