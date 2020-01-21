defmodule ChromicPDF.JsonRPC do
  @moduledoc false

  alias ChromicPDF.JsonRPCState

  @type id :: binary()
  @type method :: binary()
  @type params :: map()
  @type result :: map()
  @type error :: map()

  @spec decode_and_classify(state :: pid(), msg :: binary()) ::
          {:response, method(), result()}
          | {:error, method(), error()}
          | {:call, id(), method(), params()}
          | {:notification, method(), params()}
  def decode_and_classify(state, msg) do
    msg
    |> decode()
    |> classify(state)
  end

  defp decode(msg) do
    Jason.decode!(msg)
  end

  defp classify(msg, state) do
    case msg do
      %{"id" => id, "result" => result} ->
        {:response, JsonRPCState.pop(state, id), result}

      %{"id" => id, "error" => error} ->
        {:error, JsonRPCState.pop(state, id), error}

      %{"id" => id, "method" => method, "params" => params} ->
        {:call, id, method, params}

      %{"method" => method, "params" => params} ->
        {:notification, method, params}
    end
  end

  @spec encode(state :: pid(), method(), params()) :: binary()
  # Encodes a method and params to JSON:RPC.
  def encode(state, method, params) do
    %{
      id: JsonRPCState.push(state, method),
      method: method,
      params: params
    }
    |> Jason.encode!()
  end
end
