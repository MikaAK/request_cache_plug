defmodule RequestCache.Util do
  require Logger

  @moduledoc false

  # def parse_gql_name(query_string) do
  #   case Regex.run(~r/^(?:query) ([^\({]+(?=\(|{))/, query_string, capture: :all_but_first) do
  #     [query_name] -> String.trim(query_name)
  #     _ -> nil
  #   end
  # end

  def create_key(url_path, query_string) do
    "#{url_path}:#{hash_string(query_string)}"
  end

  defp hash_string(query_string) do
    :md5 |> :crypto.hash(query_string) |> Base.encode16(padding: false)
  end

  def log_cache_disabled_message do
    Logger.debug("RequestCache requested but hasn't been enabled, ensure query has a name and the RequestCache.Plug is part of your Endpoint")
  end

  def verbose_log(message) do
    if RequestCache.Config.verbose?() do
      Logger.debug(message)
    end
  end
end
