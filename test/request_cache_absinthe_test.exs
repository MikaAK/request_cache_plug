defmodule RequestCacheAbsintheTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  use Plug.Test

  alias RequestCache.Support.EnsureCalledOnlyOnce

  defmodule Schema do
    use Absinthe.Schema

    query do
      field :hello, :string do
        resolve fn _, %{context: %{call_pid: pid}} ->
          EnsureCalledOnlyOnce.call(pid)
          RequestCache.store("Hello", :timer.seconds(100))
        end
      end

      field :hello_world, :string do
        middleware RequestCache.Middleware, ttl: :timer.seconds(100)

        resolve fn _, %{context: %{call_pid: pid}} ->
          EnsureCalledOnlyOnce.call(pid)
          {:ok, "Hello2"}
        end
      end

      field :hello_error, :string do
        resolve fn _, %{context: %{call_pid: pid}} ->
          EnsureCalledOnlyOnce.call(pid)
          {:ok, "HelloError"}
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
      init_opts: [
        schema: RequestCacheAbsintheTest.Schema
      ]
  end

  defmodule Router do
    use Plug.Router

    plug RequestCache.Plug

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
  @query_2 "query Hello2 { helloWorld }"
  @query_error "query HelloError { helloError }"
  @unnamed_query "query { hello }"

  setup_all do
    {:ok, _pid} = RequestCache.ConCacheStore.start_link()

    :ok
  end

  setup do
    {:ok, pid} = EnsureCalledOnlyOnce.start_link()

    %{call_pid: pid}
  end

  test "allows you to use middleware before a resolver to cache the results of the request", %{call_pid: pid} do
    conn = :get
      |> conn(graphql_url(@query_2))
      |> Absinthe.Plug.put_options(context: %{call_pid: pid})
      |> Router.call([])

    assert conn.resp_body === :get
      |> conn(graphql_url(@query_2))
      |> Absinthe.Plug.put_options(context: %{call_pid: pid})
      |> Router.call([])
      |> Map.get(:resp_body)
  end

  test "allows you to use &store/2 in a resolver to cache the results of the request", %{call_pid: pid} do
    conn = :get
      |> conn(graphql_url(@query))
      |> Absinthe.Plug.put_options(context: %{call_pid: pid})
      |> Router.call([])

    assert conn.resp_body === :get
      |> conn(graphql_url(@query))
      |> Absinthe.Plug.put_options(context: %{call_pid: pid})
      |> Router.call([])
      |> Map.get(:resp_body)
  end

  test "throws an error when called twice without cache", %{call_pid: pid} do
    conn = :get
      |> conn(graphql_url(@query_error))
      |> Absinthe.Plug.put_options(context: %{call_pid: pid})
      |> Router.call([])

    assert_raise Plug.Conn.WrapperError, fn ->
      assert conn.resp_body === :get
        |> conn(graphql_url(@query_error))
        |> Absinthe.Plug.put_options(context: %{call_pid: pid})
        |> Router.call([])
        |> Map.get(:resp_body)
    end
  end

  test "logs an error if router doesn't have RequestCache.Plug", %{call_pid: pid} do
    assert capture_log(fn ->
      :get
        |> conn(graphql_url(@query))
        |> Absinthe.Plug.put_options(context: %{call_pid: pid})
        |> RouterWithoutPlug.call([])
        |> Map.get(:resp_body)
    end) =~ "RequestCache requested"
  end

  test "unammed queries don't cache but are allowed through", %{call_pid: pid} do
    :get
      |> conn(graphql_url(@unnamed_query))
      |> Absinthe.Plug.put_options(context: %{call_pid: pid})
      |> Router.call([])

    assert_raise Plug.Conn.WrapperError, fn ->
      :get
        |> conn(graphql_url(@unnamed_query))
        |> Absinthe.Plug.put_options(context: %{call_pid: pid})
        |> Router.call([])
        |> Map.get(:resp_body)
    end
  end

  test "allows you to use `cache` key inside opts to override specific cache for a request" do
  end

  defp graphql_url(query) do
    "/graphql?#{URI.encode_query(%{query: query})}"
  end
end
