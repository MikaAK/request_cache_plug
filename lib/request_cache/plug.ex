defmodule RequestCache.Plug do
  require Logger

  @moduledoc """
  This plug allows you to cache GraphQL requests based off their query name and
  variables. This should be placed right after telemetry and before parsers so that it can
  stop any processing of the requests and immediatley return a response.

  Please see `RequestCache` for more details
  """

  @behaviour Plug

  # This is compile time so we can check quicker
  @graphql_paths RequestCache.Config.graphql_paths()

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{request_path: path, method: "GET"} = conn, _) when path not in @graphql_paths do
    cache_key = rest_cache_key(conn)

    case RequestCache.ConCacheStore.get(cache_key) do
      {:ok, nil} -> conn |> enable_request_cache_for_conn |> cache_before_send_if_requested(cache_key)

      {:ok, cached_result} -> halt_and_return_result(conn, cached_result)

      {:error, e} ->
        Logger.error("[RequestCache.Plug] #{e}")

        e
    end
  end

  @impl Plug
  def call(%Plug.Conn{request_path: path, method: "GET"} = conn, _) when path in @graphql_paths do
    case fetch_query(conn) do
      nil -> conn
      {query_name, variables} ->
        maybe_return_cached_result(conn, query_name, variables)
    end
  end

  @impl Plug
  def call(conn, _), do: conn

  defp maybe_return_cached_result(conn, query_name, variables) do
    cache_key = create_key(query_name, variables)


    case RequestCache.ConCacheStore.get(cache_key) do
      {:ok, nil} -> conn |> enable_request_cache_for_conn |> cache_before_send_if_requested(cache_key)
      {:ok, cached_result} -> halt_and_return_result(conn, cached_result)
      {:error, e} ->
        Logger.error("[RequestCache.Plug] #{e}")

        e
    end
  end

  defp halt_and_return_result(conn, result) do
    conn |> Plug.Conn.halt |> Plug.Conn.send_resp(200, result)
  end

  defp rest_cache_key(%Plug.Conn{request_path: path} = conn) do
    case Plug.Conn.fetch_query_params(conn) do
      %{query_params: query_params} when query_params !== "" ->
        create_key(path, query_params)

      _ ->
        create_key(path, %{})
    end
  end

  defp create_key(query_name, variables) do
    "#{query_name}:#{:erlang.phash2(variables)}"
  end

  defp cache_before_send_if_requested(conn, cache_key) do
    Plug.Conn.register_before_send(conn, fn new_conn ->
      if enabled_for_request?(new_conn) do
        with :ok <- request_cache_module(new_conn).put(cache_key, request_cache_ttl(new_conn), new_conn.resp_body) do
          Logger.debug("[RequestCache.Plug] Successfuly put #{cache_key} into cache\n#{new_conn.resp_body}")
        end

        new_conn
      else
        new_conn
      end
    end)
  end

  defp request_cache_module(conn) do
    path = [conn_private_key(), :request, :cache]

    get_in(conn.private, path) || get_in(conn.private || %{}, [:absinthe, :context | path])
  end

  defp request_cache_ttl(conn) do
    conn.private[conn_private_key()][:request][:ttl]
  end

  defp enabled_for_request?(conn) do
    not is_nil(get_in(conn.private, [conn_private_key(), :request])) or
    not is_nil(get_in(conn.private, [:absinthe, :context, conn_private_key(), :request]))
  end

  defp fetch_query(conn) do
    case Plug.Conn.fetch_query_params(conn) do
      %{query_params: %{"query" => query} = params} ->
        query_name = parse_gql_name(query)

        if query_name do
          {query_name, params["variables"] || %{}}
        end

      _ -> nil
    end
  end

  defp parse_gql_name(query_string) do
    case Regex.run(~r/^(?:query) ([^\({]+(?=\(|{))/, query_string, capture: :all_but_first) do
      [query_name] -> String.trim(query_name)
      _ -> nil
    end
  end

  if RequestCache.Application.dependency_found?(:absinthe_plug) do
    defp enable_request_cache_for_conn(conn) do
      context = conn.private[:absinthe][:context] || %{}

      conn
        |> Plug.Conn.put_private(conn_private_key(), enabled?: true)
        |> Absinthe.Plug.put_options(context: Map.put(context, conn_private_key(), enabled?: true))
    end
  else
    defp enable_request_cache_for_conn(conn) do
      Plug.Conn.put_private(conn, conn_private_key(), enabled?: true)
    end
  end

  def store_request(conn, opts) when is_list(opts) do
    if conn.private[conn_private_key()][:enabled?] do
      Plug.Conn.put_private(conn, conn_private_key(),
        enabled?: true,
        request: merge_default_opts(opts)
      )
    else
      raise_cache_disabled_exception()
    end
  end

  def store_request(conn, ttl) when is_integer(ttl) do
    if conn.private[conn_private_key()][:enabled?] do
      Plug.Conn.put_private(conn, conn_private_key(),
        enabled?: true,
        request: [ttl: ttl, cache: RequestCache.Config.request_cache_module()]
      )
    else
      raise_cache_disabled_exception()
    end
  end

  defp raise_cache_disabled_exception do
    raise "RequestCache requestsed but hasn't been enabled, ensure query has a name and the RequestCache.Plug is part of your Endpoint"
  end

  defp merge_default_opts(opts) do
    Keyword.merge([
      ttl: RequestCache.Config.default_ttl(),
      cache: RequestCache.Config.request_cache_module()
    ], opts)
  end

  defp conn_private_key do
    RequestCache.Config.conn_private_key()
  end
end
