defmodule ChromicPDF.JsonRPCState do
  @moduledoc false

  use Agent

  def start_link do
    Agent.start_link(fn ->
      %{
        waiting_calls: %{},
        call_id: 1
      }
    end)
  end

  def push(pid, method) do
    Agent.get_and_update(pid, fn %{call_id: call_id, waiting_calls: waiting_calls} ->
      {call_id, %{call_id: call_id + 1, waiting_calls: Map.put(waiting_calls, call_id, method)}}
    end)
  end

  def pop(pid, call_id) do
    Agent.get_and_update(pid, fn %{waiting_calls: waiting_calls} = state ->
      {method, new_waiting_calls} = Map.pop(waiting_calls, call_id)
      {method, %{state | waiting_calls: new_waiting_calls}}
    end)
  end
end
