defmodule RequestCache do
  defdelegate store(%Plug.Conn{}, ttl), to: RequestCache.Plug, as: :store_request

  if Enum.any?(Application.loaded_applications(), fn {dep_name, _, _} -> dep_name === :absinthe end) do
    defdelegate store(%Absinthe.Resolution{}, ttl), to: RequestCache.Middleware,
      as: :store_resolution
  end
end
