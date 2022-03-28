defmodule RequestCache.Support.EnsureCalledOnlyOnce do
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
