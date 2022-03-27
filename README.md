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

