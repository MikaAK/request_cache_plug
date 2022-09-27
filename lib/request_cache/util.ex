defmodule RequestCache.Util do
  require Logger

  @moduledoc false

  @doc """
  Extracts the query and variables query parameters from the given Plug.Conn

        iex> {:error, :query_not_found} = RequestCache.Util.fetch_query(%Plug.Conn{query_params: nil})

        iex> {:ok, "testQuery", nil} = RequestCache.Util.fetch_query(%Plug.Conn{query_params: %{"query" => "testQuery"}})

        iex> {:ok, "testQuery", "one=one"} = RequestCache.Util.fetch_query(%Plug.Conn{query_params: %{"query" => "testQuery", "variables" => "one=one"}})

        iex> {:ok, "query Testing {allAlerts {alertDetails {message}}}", nil} = RequestCache.Util.fetch_query(%Plug.Conn{query_params: %{"query" => "query Testing {allAlerts {alertDetails {message}}}", "variables" => nil}})
  """
  @spec fetch_query(%Plug.Conn{}) :: {:ok, String.t(), String.t()} | {:query_not_found}
  def fetch_query(conn) do
    case Plug.Conn.fetch_query_params(conn) do
      %{query_params: %{"query" => query, "variables" => variables}} ->
        {:ok, query, variables}

      %{query_params: %{"query" => query}} ->
        {:ok, query, nil}

      _ ->
        {:error, :query_not_found}
    end
  end

  @doc """
  Extracts the GQL query name from the query.

        iex> {:error, :query_name_not_found} = RequestCache.Util.extract_query_name("query")

        iex> {:ok, "Testing"} = RequestCache.Util.extract_query_name("query Testing {allAlerts {alertDetails {message}}}")
  """
  @spec extract_query_name(String.t()) :: {:ok, String.t()} | {:query_name_not_found}
  def extract_query_name(query_string) do
    case Regex.run(~r/^(?:query) ([^\({]+(?=\(|{))/, query_string, capture: :all_but_first) do
      [query_name] ->
        {:ok, String.trim(query_name)}

      _ ->
        {:error, :query_name_not_found}
    end
  end

  def merge_default_opts(opts) do
    Keyword.merge([
      ttl: RequestCache.Config.default_ttl(),
      cache: RequestCache.Config.request_cache_module()
    ], opts)
  end

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
