defmodule RequestCachePlugTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import ExUnit.CaptureLog

  alias RequestCache.Support.EnsureCalledOnlyOnce

  defmodule Router do
    use Plug.Router

    plug RequestCache.Plug

    plug :match
    plug :dispatch

    match "/my_route" do
      EnsureCalledOnlyOnce.call(conn.private[:call_pid])

      conn
        |> RequestCache.store(:timer.seconds(20))
        |> send_resp(200, Jason.encode!(%{test: Enum.random(1..100_000_000)}))
    end

    match "/my_route/:param" do
      conn
        |> RequestCache.store(:timer.seconds(20))
        |> send_resp(200, Jason.encode!(%{test: Enum.random(1..100_000_000)}))
    end
  end

  defmodule EnsureCalledOnlyOncePlug do
    @behaviour Plug

    @impl Plug
    def init(opts) do
      opts
    end

    @impl Plug
    def call(conn, _opts) do
      EnsureCalledOnlyOnce.call(conn.private[:call_pid])

      conn
    end
  end

  defmodule RouterWithBreakingPlug do
    use Plug.Router

    plug RequestCache.Plug
    plug RequestCachePlugTest.EnsureCalledOnlyOncePlug

    plug :match
    plug :dispatch

    match "/my_route" do
      conn
        |> RequestCache.store(:timer.seconds(20))
        |> send_resp(200, Jason.encode!(%{test: Enum.random(1..100_000_000)}))
    end
  end

  defmodule RouterWithBreakingPlugDefaultTTL do
    use Plug.Router

    plug RequestCache.Plug
    plug RequestCachePlugTest.EnsureCalledOnlyOncePlug

    plug :match
    plug :dispatch

    match "/my_route_default_ttl" do
      conn
      |> RequestCache.store()
      |> send_resp(200, Jason.encode!(%{test: Enum.random(1..100_000_000)}))
    end
  end

  defmodule RouterWithoutPlug do
    use Plug.Router

    plug :match
    plug :dispatch

    match "/my_route" do
      conn
        |> RequestCache.store(:timer.seconds(20))
        |> send_resp(200, Jason.encode!(%{test: Enum.random(1..100_000_000)}))
    end
  end

  setup do
    {:ok, pid} = EnsureCalledOnlyOnce.start_link()

    %{caller_pid: pid}
  end

  test "stops any plug from running if cache is found", %{caller_pid: pid} do
    assert %Plug.Conn{} = :get
      |> conn("/my_route")
      |> RequestCache.Support.Utils.ensure_default_opts()
      |> put_private(:call_pid, pid)
      |> RouterWithBreakingPlug.call([])

    assert %Plug.Conn{} = :get
      |> conn("/my_route")
      |> RequestCache.Support.Utils.ensure_default_opts()
      |> put_private(:call_pid, pid)
      |> RouterWithBreakingPlug.call([])
  end

  test "stops any plug from running if cache using default ttl is found", %{caller_pid: pid} do
    assert %Plug.Conn{} = :get
      |> conn("/my_route_default_ttl")
      |> RequestCache.Support.Utils.ensure_default_opts()
      |> put_private(:call_pid, pid)
      |> RouterWithBreakingPlugDefaultTTL.call([])

    assert %Plug.Conn{} = :get
      |> conn("/my_route_default_ttl")
      |> RequestCache.Support.Utils.ensure_default_opts()
      |> put_private(:call_pid, pid)
      |> RouterWithBreakingPlugDefaultTTL.call([])
  end

  test "throws an error if router doesn't have RequestCache.Plug", %{caller_pid: pid} do
    assert capture_log(fn ->
      :get
        |> conn("/my_route")
        |> put_private(:call_pid, pid)
        |> RouterWithoutPlug.call([])
    end) =~ "RequestCache requested"
  end

  test "includes proper headers with when served from the cache", %{
    caller_pid: pid
  } do
    route = "/my_route/html"
    assert %Plug.Conn{resp_headers: uncached_headers} =
             :get
             |> conn(route)
             |> RequestCache.Support.Utils.ensure_default_opts()
             |> put_private(:call_pid, pid)
             |> Router.call([])

    assert uncached_headers === [
       {"cache-control", "max-age=0, private, must-revalidate"}
    ]

    assert %Plug.Conn{resp_headers: resp_headers} =
             :get
             |> conn(route)
             |> RequestCache.Support.Utils.ensure_default_opts()
             |> put_private(:call_pid, pid)
             |> Router.call([])

    assert resp_headers === [
             {"cache-control", "max-age=0, private, must-revalidate"},
             {"rc-cache-status", "HIT"},
             {"content-type", "application/json; charset=utf-8"}
           ]
  end

  test "allows for for custom content-type header and returns it when served from the cache", %{
    caller_pid: pid
  } do
    route = "/my_route/:param"
    assert %Plug.Conn{resp_headers: uncached_headers} =
             :get
             |> conn(route)
             |> RequestCache.Support.Utils.ensure_default_opts()
             |> put_private(:call_pid, pid)
             |> Router.call([])

    assert uncached_headers === [
       {"cache-control", "max-age=0, private, must-revalidate"}
    ]

    assert %Plug.Conn{resp_headers: resp_headers} =
             :get
             |> conn(route)
             |> RequestCache.Support.Utils.ensure_default_opts()
             |> put_private(:call_pid, pid)
             |> put_resp_content_type("text/html")
             |> Router.call([])

    assert resp_headers === [
             {"cache-control", "max-age=0, private, must-revalidate"},
             {"content-type", "text/html; charset=utf-8"},
             {"rc-cache-status", "HIT"}
           ]
  end

  test "allows you to use `cache` key inside opts to override specific cache for a request" do
  end
end
