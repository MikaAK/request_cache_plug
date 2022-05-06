defmodule RequestCache.Support.Utils do
  @moduledoc false

  alias Plug.Conn

  def ensure_default_opts(conn) do
    Conn.put_private(conn, RequestCache.Config.conn_private_key(), request: RequestCache.Util.merge_default_opts([]))
  end

  def graphql_conn(), do: build_conn("GET", "/graphql") |> ensure_default_opts

  def rest_conn(), do: build_conn("GET", "/entity") |> ensure_default_opts

  @spec build_conn(atom | binary, binary, binary | list | map | nil) :: Conn.t
  def build_conn(method, path, params_or_body \\ nil) do
    Plug.Adapters.Test.Conn.conn(%Conn{}, method, path, params_or_body)
    |> Conn.put_private(:plug_skip_csrf_protection, true)
    |> Conn.put_private(:phoenix_recycled, true)
  end
end
