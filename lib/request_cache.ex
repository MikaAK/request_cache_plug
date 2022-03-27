defmodule RequestCache do
  @moduledoc """
  #{File.read!("./README.md")}
  """

  def store(%Plug.Conn{} = conn, opts_or_ttl) do
    RequestCache.Plug.store_request(conn, opts_or_ttl)
  end

  if RequestCache.Application.dependency_found?(:absinthe) do
    def store(%Absinthe.Resolution{} = conn, opts_or_ttl) do
      RequestCache.Middleware.store_resolution(conn, opts_or_ttl)
    end
  end
end
