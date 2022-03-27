defmodule RequestCache do
  @moduledoc """
  #{File.read!("./README.md")}
  """

  def store(%Plug.Conn{} = conn, opts_or_ttl) do
    RequestCache.Plug.store_request(conn, opts_or_ttl)
  end

  if Enum.any?(Application.loaded_applications(), fn {dep_name, _, _} -> dep_name === :absinthe end) do
    def store(%Absinthe.Resolution{} = conn, opts_or_ttl) do
      RequestCache.Middleware.store_resolution(conn, opts_or_ttl)
    end
  end
end
