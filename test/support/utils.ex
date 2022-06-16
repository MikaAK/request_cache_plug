defmodule RequestCache.Support.Utils do
  @moduledoc false

  alias Plug.Conn

  def ensure_default_opts(conn) do
    Conn.put_private(conn, RequestCache.Config.conn_private_key(), request: RequestCache.Util.merge_default_opts([]))
  end

  def graphql_conn, do: "GET" |> build_conn("/graphql") |> ensure_default_opts

  def rest_conn, do: "GET" |> build_conn("/entity") |> ensure_default_opts

  @spec build_conn(atom | binary, binary, binary | list | map | nil) :: Conn.t
  def build_conn(method, path, params_or_body \\ nil) do
    %Conn{}
      |> Plug.Adapters.Test.Conn.conn(method, path, params_or_body)
      |> Conn.put_private(:plug_skip_csrf_protection, true)
      |> Conn.put_private(:phoenix_recycled, true)
  end
end
