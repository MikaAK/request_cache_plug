defmodule RequestCache.Support.Utils do
  @moduledoc false

  alias Plug.Conn

  def ensure_default_opts(conn) do
    Conn.put_private(conn, RequestCache.Config.conn_private_key(), request: RequestCache.Util.merge_default_opts([]))
  end
end
