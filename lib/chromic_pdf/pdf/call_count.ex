defmodule ChromicPDF.CallCount do
  @moduledoc false

  use Agent

  def start_link do
    Agent.start_link(fn -> 1 end)
  end

  def bump(pid) do
    Agent.get_and_update(pid, &{&1, &1 + 1})
  end
end
