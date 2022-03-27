defmodule RequestCache.Plug do
  @moduledoc """
  This plug allows you to cache GraphQL requests based off their query name and
  variables. This should be placed right after telemetry and before parsers so that it can
  stop any processing of the requests and immediatley return a response.

  Please see `RequestCache` for more details
  """

  @behaviour Plug

  @conn_private_key :__shared_request_cache__

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _) do
    case fetch_query(conn) do
      nil -> enable_request_cache_for_conn(conn)
      {query_name, variables} ->
        maybe_return_cached_result(conn, query_name, variables)
    end
  end

  defp maybe_return_cached_result(conn, query_name, variables) do
    cache_key = create_key(query_name, variables)

    case Store.get(cache_key) do
      {:ok, nil} -> conn |> enable_request_cache_for_conn |> cache_before_send_if_requested(cache_key)
      {:ok, cached_result} -> conn |> Plug.Conn.halt |> Plug.Conn.send_resp(200, cached_result)
    end
  end

  defp create_key(query_name, variables) do
    "#{query_name}:#{:erlang.phash2(variables)}"
  end

  defp cache_before_send_if_requested(conn, cache_key) do
    Plug.Conn.register_before_send(conn, fn new_conn ->
      if enabled_for_request?(conn) do
        Store.put(cache_key, request_cache_ttl(conn), conn.resp_body)

        new_conn
      else
        new_conn
      end
    end)
  end

  defp request_cache_ttl(conn) do
    new_conn.private[@conn_private_key][:request][:ttl]
  end

  defp enabled_for_request?(conn) do
    not is_nil(new_conn.private[@conn_private_key][:request])
  end

  defp fetch_query(conn) do
    case Plug.Conn.fetch_query_params(conn) do
      %{query_params: %{"query" => query, "variables" => variables}} ->
        query_name = parse_gql_name(query)

        {query_name, variables}

      _ -> nil
    end
  end

  defp parse_gql_name(query_string) do
    case Regex.run(~r/^(?:query) ([^\(]+(?=\())/, query_string, capture: :all_but_first) do
      [query_name] -> query_name
      _ -> nil
    end
  end

  defp enable_request_cache_for_conn(conn) do
    Plug.Conn.put_private(conn, @conn_private_key, enabled?: true)
  end

  def store_request(conn, ttl) do
    if conn.private[@conn_private_key][:enabled?] do
      Plug.Conn.put_private(conn, @conn_private_key, enabled?: true, request: [ttl: ttl])
    else
      raise "RequestCache requestsed but hasn't been enabled, ensure query has a name and the RequestCache.Plug is part of your Endpoint"
    end
  end
end
