defmodule ChromicPDF.Protocol do
  @moduledoc false

  @type call_id :: integer()

  @type method :: binary()
  @type params :: map()
  @type call :: {method(), params()}

  @type result :: map()
  @type error :: map()

  @type msg ::
          {:response, call_id(), result()}
          | {:error, call_id(), error()}
          | {:call, call_id(), call()}
          | {:notification, call()}

  @type state :: any()
  @type dispatcher :: (call() -> call_id())

  @callback init(GenServer.from(), any(), dispatcher()) ::
              {:ok, state()} | {:done, response :: any()}
  @callback handle_msg(msg(), state(), dispatcher()) :: {:ok, state()} | :done | :ignore

  defmacro __using__(_opts) do
    quote do
      @behaviour ChromicPDF.Protocol

      @impl ChromicPDF.Protocol
      def handle_msg(_msg, _state, _dispatcher) do
        :ignore
      end

      defoverridable handle_msg: 3
    end
  end

  @spec decode(data :: binary()) :: msg()
  def decode(data) do
    case Jason.decode!(data) do
      %{"id" => id, "result" => result} ->
        {:response, id, result}

      %{"id" => id, "error" => error} ->
        {:error, id, error}

      %{"id" => id, "method" => method, "params" => params} ->
        {:call, id, {method, params}}

      %{"method" => method, "params" => params} ->
        {:notification, {method, params}}
    end
  end

  @spec encode(call_id(), call()) :: binary()
  def encode(call_id, {method, params}) do
    Jason.encode!(%{id: call_id, method: method, params: params})
  end
end
