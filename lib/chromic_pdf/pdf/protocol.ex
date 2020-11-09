defmodule ChromicPDF.Protocol do
  @moduledoc false

  alias ChromicPDF.Connection.JsonRPC

  # A protocol is a sequence of JsonRPC calls and responses/notifications.
  #
  # * It is created with a client request.
  # * It's goal is to fulfill the client request.
  # * A protocol's `steps` queue is a list of functions. When it is empty, the protocol is done.
  # * Besides, a protocol has a `state` map of arbitrary values.

  @type message :: JsonRPC.message()
  @type dispatch :: (JsonRPC.call() -> JsonRPC.call_id())

  @type state :: map()
  @type error :: {:error, term()}
  @type step :: call_step() | await_step() | output_step()

  @type call_fun :: (state(), dispatch() -> state() | error())
  @type call_step :: {:call, call_fun()}

  @type await_fun :: (state(), message() -> :no_match | {:match, state()} | error())
  @type await_step :: {:await, await_fun()}

  @type output_fun :: (state() -> any())
  @type output_step :: {:output, output_fun()}

  @type result :: {:ok, any()} | {:error, term()}
  @type result_fun :: (result() -> any())

  @type t :: %__MODULE__{
          steps: [step()],
          state: state(),
          result_fun: result_fun() | nil
        }

  @enforce_keys [:steps, :state, :result_fun]
  defstruct [:steps, :state, :result_fun]

  @spec new([step()], state()) :: __MODULE__.t()
  def new(steps, initial_state \\ %{}) do
    %__MODULE__{
      steps: steps,
      state: initial_state,
      result_fun: nil
    }
  end

  @spec init(__MODULE__.t(), result_fun(), dispatch()) :: __MODULE__.t()
  def init(%__MODULE__{} = protocol, result_fun, dispatch) do
    advance(%{protocol | result_fun: result_fun}, dispatch)
  end

  defp advance(%__MODULE__{state: {:error, error}, result_fun: result_fun} = protocol, _dispatch) do
    result_fun.({:error, error})
    %{protocol | steps: []}
  end

  defp advance(%__MODULE__{steps: []} = protocol, _dispatch), do: protocol
  defp advance(%__MODULE__{steps: [{:await, _fun} | _rest]} = protocol, _dispatch), do: protocol

  defp advance(%__MODULE__{steps: [{:call, fun} | rest], state: state} = protocol, dispatch) do
    state = fun.(state, dispatch)
    advance(%{protocol | steps: rest, state: state}, dispatch)
  end

  defp advance(
         %__MODULE__{steps: [{:output, output_fun} | rest], state: state, result_fun: result_fun} =
           protocol,
         dispatch
       ) do
    result_fun.({:ok, output_fun.(state)})
    advance(%{protocol | steps: rest}, dispatch)
  end

  @spec run(__MODULE__.t(), JsonRPC.message(), dispatch()) :: __MODULE__.t()
  def run(protocol, msg, dispatch) do
    protocol
    |> test(msg)
    |> advance(dispatch)
  end

  defp test(%__MODULE__{steps: [{:await, fun} | rest], state: state} = protocol, msg) do
    case fun.(state, msg) do
      :no_match -> protocol
      {:match, state} -> %{protocol | steps: rest, state: state}
      {:error, error} -> %{protocol | steps: [], state: {:error, error}}
    end
  end

  @spec finished?(__MODULE__.t()) :: boolean()
  def finished?(%__MODULE__{steps: []}), do: true
  def finished?(%__MODULE__{}), do: false
end
