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
  @allowed_graphql_methods RequestCache.Config.allowed_graphql_methods()
  @allowed_rest_methods RequestCache.Config.allowed_rest_methods()
  @request_cache_header "rc-cache-status"

  def request_cache_header, do: @request_cache_header

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, opts) do
    if RequestCache.Config.enabled?() do
      Util.verbose_log("[RequestCache.Plug] Hit request cache while enabled")

      call_for_api_type(conn, opts)
    else
      Util.verbose_log("[RequestCache.Plug] Hit request cache while disabled")

      conn
    end
  end

  defp call_for_api_type(%Plug.Conn{
    request_path: path,
    method: method,
    query_string: query_string
  } = conn, opts) when path in @graphql_paths and method in @allowed_graphql_methods do
    Util.verbose_log("[RequestCache.Plug] GraphQL query detected")

    maybe_return_cached_result(conn, opts, path, query_string)
  end

  defp call_for_api_type(%Plug.Conn{
    request_path: path,
    method: method
  } = conn, opts) when path not in @graphql_paths and method in @allowed_rest_methods do
    Util.verbose_log("[RequestCache.Plug] REST path detected")

    cache_key = rest_cache_key(conn)

    case request_cache_module(conn, opts).get(cache_key) do
      {:ok, nil} ->
        Metrics.inc_rest_cache_miss(%{cache_key: cache_key})
        Util.verbose_log("[RequestCache.Plug] REST enabling cache for conn and will cache if set")

        conn
        |> enable_request_cache_for_conn
        |> cache_before_send_if_requested(cache_key, opts)

      {:ok, cached_result} ->
        Metrics.inc_rest_cache_hit(%{cache_key: cache_key})
        Util.verbose_log("[RequestCache.Plug] Returning cached result for #{cache_key}")

        halt_and_return_result(conn, cached_result)

      {:error, e} ->
        log_error(e, conn, opts)

        enable_request_cache_for_conn(conn)
    end
  end

  defp call_for_api_type(conn, _opts), do: conn

  defp maybe_return_cached_result(conn, opts, request_path, query_string) do
    cache_key = Util.create_key(request_path, query_string)

    case request_cache_module(conn, opts).get(cache_key) do
      {:ok, nil} ->
        Metrics.inc_graphql_cache_miss(event_metadata(conn, cache_key, opts))

        conn
        |> enable_request_cache_for_conn
        |> cache_before_send_if_requested(cache_key, opts)

      {:ok, cached_result} ->
        Metrics.inc_graphql_cache_hit(event_metadata(conn, cache_key, opts))
        Util.verbose_log("[RequestCache.Plug] Returning cached result for #{cache_key}")

        halt_and_return_result(conn, cached_result)

      {:error, e} ->
        log_error(e, conn, opts)

        enable_request_cache_for_conn(conn)
    end
  end

  defp halt_and_return_result(conn, result) do
    conn
    |> Plug.Conn.halt()
    |> Plug.Conn.put_resp_header(@request_cache_header, "HIT")
    |> maybe_put_content_type(result)
    |> Plug.Conn.send_resp(200, result)
  end

  defp maybe_put_content_type(conn, result) do
    case Plug.Conn.get_resp_header(conn, "content-type") do
      [_ | _] -> conn
      [] ->
        cond do
          String.starts_with?(result, ["{", "["]) -> Plug.Conn.put_resp_content_type(conn, "application/json")
          String.starts_with?(result, ["<"]) -> Plug.Conn.put_resp_content_type(conn, "text/html")

          true -> conn
        end
    end
  end

  defp rest_cache_key(%Plug.Conn{request_path: path, query_string: query_string}) do
    Util.create_key(path, query_string)
  end

  defp cache_before_send_if_requested(conn, cache_key, opts) do
    Plug.Conn.register_before_send(conn, fn new_conn ->
      if enabled_for_request?(new_conn) do
        Util.verbose_log("[RequestCache.Plug] Cache enabled before send, setting into cache...")
        ttl = request_cache_ttl(new_conn, opts)

        with :ok <- request_cache_module(new_conn, opts).put(cache_key, ttl, to_string(new_conn.resp_body)) do
          Metrics.inc_cache_put(event_metadata(conn, cache_key, opts))

          Util.verbose_log("[RequestCache.Plug] Successfully put #{cache_key} into cache\n#{new_conn.resp_body}")
        end

        new_conn
      else
        Util.verbose_log("[RequestCache.Plug] Cache disabled in before_send callback")

        new_conn
      end
    end)
  end

  @spec event_metadata(Plug.Conn.t, String.t, Keyword.t) :: map()
  defp event_metadata(conn, cache_key, opts) do
    %{
      cache_key: cache_key,
      labels: request_cache_labels(conn),
      ttl: request_cache_ttl(conn, opts)
    }
  end

  defp request_cache_module(conn, opts) do
    conn_request(conn)[:cache] || opts[:cache] || RequestCache.Config.request_cache_module()
  end

  defp request_cache_ttl(conn, opts) do
    conn_request(conn)[:ttl] || opts[:ttl] || RequestCache.Config.default_ttl()
  end

  defp request_cache_labels(conn) do
    conn_request(conn)[:labels]
  end

  defp request_cache_cached_errors(conn) do
    conn_request(conn)[:cached_errors] || RequestCache.Config.cached_errors()
  end

  defp enabled_for_request?(%Plug.Conn{} = conn) do
    plug_present? = !!conn_private_key_item(conn, :enabled?)
    marked_for_cache? = !!conn_private_key_item(conn, :cache_request?)

    if plug_present? do
      Util.verbose_log("[RequestCache.Plug] Plug enabled for request")
    end

    if marked_for_cache? do
      Util.verbose_log("[RequestCache.Plug] Plug has been marked for cache")
    end

    plug_present? && marked_for_cache? && response_error_and_cached?(conn)
  end

  defp response_error_and_cached?(%Plug.Conn{status: 200, request_path: path}) when path not in @graphql_paths do
    true
  end

  defp response_error_and_cached?(%Plug.Conn{status: 200, request_path: path} = conn) when path in @graphql_paths do
    empty_errors? = String.contains?(conn.resp_body, empty_errors_pattern())
    no_errors? = !String.contains?(conn.resp_body, error_pattern())

    empty_errors? or
    no_errors? or
    gql_resp_has_known_error?(request_cache_cached_errors(conn), conn.resp_body)
  end

  defp response_error_and_cached?(%Plug.Conn{status: status} = conn) do
    cached_error_codes = request_cache_cached_errors(conn)

    cached_error_codes !== [] and
    (cached_error_codes === :all or Plug.Conn.Status.reason_atom(status) in cached_error_codes)
  end

  defp gql_resp_has_known_error?([], _resp_body), do: false
  defp gql_resp_has_known_error?(:all, _resp_body), do: true

  defp gql_resp_has_known_error?(cached_errors, resp_body) do
    String.contains?(resp_body, error_codes_pattern(cached_errors))
  end

  def empty_errors_pattern, do: :binary.compile_pattern("\"errors\": []")
  def error_pattern, do: :binary.compile_pattern("\"errors\":")

  def error_codes_pattern(cached_errors) do
    cached_errors
      |> Enum.flat_map(&["code\":\"#{&1}", "code\" :\"#{&1}", "code\": \"#{&1}", "code\" : \"#{&1}"])
      |> :binary.compile_pattern
  end


  defp conn_request(%Plug.Conn{} = conn) do
    conn_private_key_item(conn, :request) || []
  end

  defp conn_private_key_item(%Plug.Conn{private: private}, name) do
    get_in(private, [conn_private_key(), name])
    || get_in(private, [:absinthe, :context, conn_private_key(), name])
  end

  if RequestCache.Application.dependency_found?(:absinthe_plug) do
    defp enable_request_cache_for_conn(conn) do
      context = conn.private[:absinthe][:context] || %{}

      conn
        |> deep_merge_to_private(enabled?: true)
        |> Absinthe.Plug.put_options(
          context: Util.deep_merge(context, %{conn_private_key() => [enabled?: true]})
        )
    end
  else
    defp enable_request_cache_for_conn(conn) do
      deep_merge_to_private(conn, enabled?: true)
    end
  end

  def store_request(conn, opts) when is_list(opts) do
    if conn.private[conn_private_key()][:enabled?] do
      Util.verbose_log("[RequestCache.Plug] Storing REST request in #{conn_private_key()}")

      deep_merge_to_private(conn,
        cache_request?: true,
        request: opts
      )
    else
      Util.log_cache_disabled_message()

      conn
    end
  end

  def store_request(conn, ttl) when is_integer(ttl) do
    store_request(conn, [ttl: ttl])
  end

  defp conn_private_key do
    RequestCache.Config.conn_private_key()
  end

  defp deep_merge_to_private(conn, params) do
    (conn.private[conn_private_key()] || [])
      |> Util.deep_merge(params)
      |> then(&Plug.Conn.put_private(conn, conn_private_key(), &1))
  end

  defp log_error(error, conn, opts) do
    {:current_stacktrace, stacktrace} = Process.info(self(), :current_stacktrace)

    Logger.error(
      "[RequestCache.Plug] recieved an error from #{inspect(request_cache_module(conn, opts))}",
      [crash_reason: {error, stacktrace}]
    )
  end
end
