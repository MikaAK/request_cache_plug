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

  test "throws an error if router doesn't have RequestCache.Plug", %{caller_pid: pid} do
    assert capture_log(fn ->
      :get
        |> conn("/my_route")
        |> put_private(:call_pid, pid)
        |> RouterWithoutPlug.call([])
    end) =~ "RequestCache requested"
  end

  test "includes Content-Type header with value application/json from the cache", %{
    caller_pid: pid
  } do
    assert %Plug.Conn{} =
             :get
             |> conn("/my_route")
             |> RequestCache.Support.Utils.ensure_default_opts()
             |> put_private(:call_pid, pid)
             |> Router.call([])

    assert %Plug.Conn{resp_headers: resp_headers} =
             :get
             |> conn("/my_route")
             |> RequestCache.Support.Utils.ensure_default_opts()
             |> put_private(:call_pid, pid)
             |> Router.call([])

    assert resp_headers === [
             {"cache-control", "max-age=0, private, must-revalidate"},
             {"content-type", "application/json; charset=utf-8"}
           ]
  end

  test "allows you to use `cache` key inside opts to override specific cache for a request" do
  end
end
