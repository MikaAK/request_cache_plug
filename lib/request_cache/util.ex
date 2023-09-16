defmodule RequestCache.Util do
  require Logger

  @moduledoc false

  @whitelisted_modules [DateTime, NaiveDateTime, Date, Time, File.Stat, MapSet, Regex, URI, Version]

  def create_key(url_path, query_string) do
    "#{url_path}:#{hash_string(query_string)}"
  end

  defp hash_string(query_string) do
    :md5 |> :crypto.hash(query_string) |> Base.encode16(padding: false)
  end

  def log_cache_disabled_message do
    Logger.warning("RequestCache requested but hasn't been enabled, ensure RequestCache.Plug is part of your endpoint.ex file")
  end

  def verbose_log(message) do
    if RequestCache.Config.verbose?() do
      Logger.debug(message)
    end
  end

  def deep_merge(list_a, list_b) when is_list(list_a) and is_list(list_b) do
    Keyword.merge(list_a, list_b, fn
      _k, _, %struct{} = right when struct in @whitelisted_modules -> right
      _k, left, right when is_map(left) and is_map(right) -> deep_merge(left, right)
      _k, left, right when is_list(left) and is_list(right) -> deep_merge(left, right)
      _, _, right -> right
    end)
  end

  def deep_merge(map_a, map_b) do
    Map.merge(map_a, map_b, fn
      _k, _, %struct{} = right when struct in @whitelisted_modules -> right
      _k, left, right when is_map(left) and is_map(right) -> deep_merge(left, right)
      _k, left, right when is_list(left) and is_list(right) -> deep_merge(left, right)
      _, _, right -> right
    end)
  end
end
