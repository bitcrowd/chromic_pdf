defmodule ChromicPDF.JsonRPCChannel do
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

  @type id :: binary()
  @type method :: binary()
  @type params :: map()
  @type result :: map()
  @type error :: map()

  @type decoded_message ::
          {:response, method(), result()}
          | {:error, method(), error()}
          | {:call, id(), method(), params()}
          | {:notification, method(), params()}

  @spec decode(pid(), msg :: binary()) :: decoded_message()
  def decode(pid, msg) do
    msg
    |> Jason.decode!()
    |> classify(pid)
  end

  defp classify(msg, pid) do
    case msg do
      %{"id" => id, "result" => result} ->
        {:response, pop(pid, id), result}

      %{"id" => id, "error" => error} ->
        {:error, pop(pid, id), error}

      %{"id" => id, "method" => method, "params" => params} ->
        {:call, id, method, params}

      %{"method" => method, "params" => params} ->
        {:notification, method, params}
    end
  end

  @spec encode(pid(), {:call, method(), params()}) :: binary()
  # Encodes a method and params to JSON:RPC.
  def encode(pid, {:call, method, params}) do
    %{
      id: push(pid, method),
      method: method,
      params: params
    }
    |> Jason.encode!()
  end

  defp push(pid, method) do
    Agent.get_and_update(pid, fn %{call_id: call_id, waiting_calls: waiting_calls} ->
      {call_id, %{call_id: call_id + 1, waiting_calls: Map.put(waiting_calls, call_id, method)}}
    end)
  end

  defp pop(pid, call_id) do
    Agent.get_and_update(pid, fn %{waiting_calls: waiting_calls} = state ->
      {method, new_waiting_calls} = Map.pop(waiting_calls, call_id)
      {method, %{state | waiting_calls: new_waiting_calls}}
    end)
  end
end
