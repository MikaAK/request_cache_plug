defmodule RequestCache.Plug do
  require Logger

  alias RequestCache.{Util, Metrics}

  @moduledoc """
  This plug allows you to cache GraphQL requests based off their query name and
  variables. This should be placed right after telemetry and before parsers so that it can
  stop any processing of the requests and immediately return a response.

  Please see `RequestCache` for more details
  """

  @behaviour Plug

  # This is compile time so we can check quicker
  @graphql_paths RequestCache.Config.graphql_paths()
  @request_cache_header "rc-cache-status"

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _) do
    if RequestCache.Config.enabled?() do
      Util.verbose_log("[RequestCache.Plug] Hit request cache while enabled")
      call_for_api_type(conn)
    else
      Util.verbose_log("[RequestCache.Plug] Hit request cache while disabled")

      conn
    end
  end

  defp call_for_api_type(%Plug.Conn{request_path: path, method: "GET", query_string: query_string} = conn) when path in @graphql_paths do
    Util.verbose_log("[RequestCache.Plug] GraphQL query detected")

    maybe_return_cached_result(conn, path, query_string)
  end

  defp call_for_api_type(%Plug.Conn{request_path: path, method: "GET"} = conn) when path not in @graphql_paths do
    Util.verbose_log("[RequestCache.Plug] REST path detected")

    cache_key = rest_cache_key(conn)

    case request_cache_module(conn).get(cache_key) do
      {:ok, nil} ->
        Metrics.inc_rest_cache_miss(rest_event_metadata(conn, cache_key))
        Util.verbose_log("[RequestCache.Plug] REST enabling cache for conn and will cache if set")

        conn
        |> enable_request_cache_for_conn
        |> cache_before_send_if_requested(cache_key)

      {:ok, cached_result} ->
        Metrics.inc_rest_cache_hit(rest_event_metadata(conn, cache_key))
        Util.verbose_log("[RequestCache.Plug] Returning cached result for #{cache_key}")

        halt_and_return_result(conn, cached_result)

      {:error, e} ->
        Logger.error("[RequestCache.Plug] #{inspect(e)}")

        enable_request_cache_for_conn(conn)
    end
  end

  defp call_for_api_type(conn), do: conn

  defp maybe_return_cached_result(conn, request_path, query_string) do
    cache_key = Util.create_key(request_path, query_string)

    case request_cache_module(conn).get(cache_key) do
      {:ok, nil} ->
        Metrics.inc_graphql_cache_miss(gql_event_metadata(conn, cache_key))

        conn
        |> enable_request_cache_for_conn
        |> cache_before_send_if_requested(cache_key)

      {:ok, cached_result} ->
        Metrics.inc_graphql_cache_hit(gql_event_metadata(conn, cache_key))
        Util.verbose_log("[RequestCache.Plug] Returning cached result for #{cache_key}")

        halt_and_return_result(conn, cached_result)

      {:error, e} ->
        Logger.error("[RequestCache.Plug] #{inspect(e)}")

        enable_request_cache_for_conn(conn)
    end
  end

  defp halt_and_return_result(conn, result) do
    conn
    |> Plug.Conn.halt()
    |> Plug.Conn.put_resp_header(@request_cache_header, "HIT")
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, result)
  end

  defp rest_cache_key(%Plug.Conn{request_path: path, query_string: query_string}) do
    Util.create_key(path, query_string)
  end

  defp cache_before_send_if_requested(conn, cache_key) do
    Plug.Conn.register_before_send(conn, fn new_conn ->
      if enabled_for_request?(new_conn) do
        Util.verbose_log("[RequestCache.Plug] Cache enabled before send, setting into cache...")
        ttl = request_cache_ttl(new_conn)
        with :ok <- request_cache_module(new_conn).put(cache_key, ttl, new_conn.resp_body) do
          Metrics.inc_cache_put(event_metadata(conn, cache_key))
          Util.verbose_log("[RequestCache.Plug] Successfully put #{cache_key} into cache\n#{new_conn.resp_body}")
        end

        new_conn
      else
        Util.verbose_log("[RequestCache.Plug] Cache disabled in before_send callback")

        new_conn
      end
    end)
  end

  defp event_metadata(conn, cache_key) do
    %{
      cache_key: cache_key,
      ttl: request_cache_ttl(conn)
    }
  end

  defp gql_event_metadata(conn, cache_key) do
    event_metadata = event_metadata(conn, cache_key)
    labels = %{labels: request_cache_gql_labels(conn)}

    Map.merge(event_metadata, labels)
  end

  defp rest_event_metadata(conn, cache_key) do
    event_metadata = event_metadata(conn, cache_key)
    labels = %{labels: request_cache_rest_labels(conn)}

    Map.merge(event_metadata, labels)
  end

  defp request_cache_module(conn) do
    conn_request(conn)[:cache] || RequestCache.Config.request_cache_module()
  end

  defp request_cache_ttl(conn) do
    conn_request(conn)[:ttl]
  end

  defp request_cache_gql_labels(conn) do
    with {:ok, query, _variables} <- Util.fetch_query(conn),
         {:ok, query_name} <- Util.extract_query_name(query) do
      query_name
      |> Macro.underscore()
      |> String.to_atom()
      |> List.wrap()
    else
      {:error, :query_not_found} -> [:query_not_found]
      {:error, :query_name_not_found} -> [:query_name_not_found]
      mismatch -> [:unknown_error, mismatch]
    end
  end

  defp request_cache_rest_labels(%{path_info: path_info}) do
    Enum.map(path_info, &String.to_atom(&1))
  end

  defp enabled_for_request?(conn) do
    conn_request(conn) !== []
  end

  defp conn_request(%{private: private}) do
    get_in(private, [conn_private_key(), :request])
    || get_in(private, [:absinthe, :context, conn_private_key(), :request])
    || []
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
        request: Util.merge_default_opts(opts)
      )
    else
      Util.log_cache_disabled_message()

      conn
    end
  end

  def store_request(conn, ttl) when is_integer(ttl) do
    if conn.private[conn_private_key()][:enabled?] do
      Plug.Conn.put_private(conn, conn_private_key(),
        enabled?: true,
        request: [ttl: ttl, cache: RequestCache.Config.request_cache_module()]
      )
    else
      Util.log_cache_disabled_message()

      conn
    end
  end

  defp conn_private_key do
    RequestCache.Config.conn_private_key()
  end
end
