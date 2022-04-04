defmodule RequestCache.Util do
  require Logger

  @moduledoc false

  def parse_gql_name(query_string) do
    case Regex.run(~r/^(?:query) ([^\({]+(?=\(|{))/, query_string, capture: :all_but_first) do
      [query_name] -> String.trim(query_name)
      _ -> nil
    end
  end

  def merge_default_opts(opts) do
    Keyword.merge([
      ttl: RequestCache.Config.default_ttl(),
      cache: RequestCache.Config.request_cache_module()
    ], opts)
  end

  def create_key(query_name, variables) do
    "#{query_name}:#{:erlang.phash2(variables)}"
  end

  def log_cache_disabled_message do
    Logger.debug("RequestCache requested but hasn't been enabled, ensure query has a name and the RequestCache.Plug is part of your Endpoint")
  end
end
