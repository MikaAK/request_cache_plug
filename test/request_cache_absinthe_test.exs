defmodule RequestCacheAbsintheTest do
  use ExUnit.Case, async: true
  use Plug.Test

  defmodule EnsureCalledOnlyOnce do
    use Agent

    def start_link do
      Agent.start_link(fn ->
        false
      end)
    end

    def call(pid) do
      if Agent.get(pid, &(&1)) do
        raise "Cannot be called more than once"
      else
        Agent.update(pid, fn _ -> true end)
      end
    end
  end

  defmodule Schema do
    use Absinthe.Schema

    query do
      field :hello, :string do
        resolve fn _, %{context: %{call_pid: pid}} ->
          EnsureCalledOnlyOnce.call(pid)
          RequestCache.store("Hello", :timer.seconds(100))
        end
      end
    end
  end

  defmodule RouterWithoutPlug do
    use Plug.Router

    plug :match
    plug :dispatch

    forward "/graphql",
      to: Absinthe.Plug,
      init_opts: [schema: RequestCacheAbsintheTest.Schema]
  end

  defmodule RouterWithEnsureOnlyCalledOnce do
    use Plug.Router

    plug RequestCache.Plug

    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
      pass: ["*/*"],
      json_decoder: Jason

    plug :match
    plug :dispatch

    forward "/graphql",
      to: Absinthe.Plug,
      init_opts: [schema: RequestCacheAbsintheTest.Schema]
  end

  defmodule Router do
    use Plug.Router

    plug RequestCache.Plug

    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json, Absinthe.Plug.Parser],
      pass: ["*/*"],
      json_decoder: Jason

    plug :match
    plug :dispatch

    forward "/graphql",
      to: Absinthe.Plug,
      init_opts: [
        schema: RequestCacheAbsintheTest.Schema,
        before_send: {RequestCache, :connect_absinthe_context_to_conn}
      ]
  end

  @query "query Hello { hello }"

  setup do
    {:ok, pid} = EnsureCalledOnlyOnce.start_link()

    %{call_pid: pid}
  end

  test "allows you to use &store/2 in a resolver to cache the results of the request", %{call_pid: pid} do
    RequestCache.ConCacheStore.start_link()

    conn = :get
      |> conn("/graphql?#{URI.encode_query(%{query: @query})}")
      |> Absinthe.Plug.put_options(context: %{call_pid: pid})
      |> Router.call([])

    assert conn.resp_body === :get
      |> conn("/graphql?#{URI.encode_query(%{query: @query})}")
      |> Absinthe.Plug.put_options(context: %{call_pid: pid})
      |> Router.call([])
      |> Map.get(:resp_body)
  end

  test "throws an error if router doesn't have RequestCache.Plug", %{call_pid: pid} do
    assert_raise Plug.Conn.WrapperError, fn ->
      :get
        |> conn("/graphql?#{URI.encode_query(%{query: @query})}")
        |> Absinthe.Plug.put_options(context: %{call_pid: pid})
        |> RouterWithoutPlug.call([])
    end
  end

  test "allows you to use `cache` key inside opts to override specific cache for a request"
end
