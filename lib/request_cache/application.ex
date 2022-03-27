defmodule RequestCache.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [

    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RequestCache.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def dependency_found?(dependency_name) do
    Enum.any?(Application.loaded_applications(), fn
      {^dependency_name, _, _} -> true
      _ -> false
    end)
  end
end

