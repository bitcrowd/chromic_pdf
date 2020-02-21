defmodule ChromicPDF.Protocol do
  @moduledoc false

  alias ChromicPDF.JsonRPC

  # A protocol is a sequence of JsonRPC calls and responses/notifications.
  #
  # * It is created with a client request.
  # * It's goal is to fulfill the client request.
  # * A protocol's `steps` queue is a list of functions. When it is empty, the protocol is done.
  # * Besides, a protocol has a `state` map of arbitrary values.

  @type message :: JsonRPC.message()
  @type dispatch :: (JsonRPC.call() -> JsonRPC.call_id())

  @type state :: map()
  @type step :: call_step() | await_step() | reply_step()

  @type call_step :: {:call, (state(), dispatch() -> state())}
  @type await_step :: {:await, (state(), message() -> :no_match | {:match, state()})}
  @type reply_step :: {:reply, (state() -> any())}

  @type t :: %__MODULE__{
          steps: [step()],
          state: state(),
          from: GenServer.from() | nil
        }

  @enforce_keys [:steps, :state, :from]
  defstruct [:steps, :state, :from]

  @spec new([step()], state()) :: __MODULE__.t()
  def new(steps, initial_state \\ %{}) do
    %__MODULE__{
      steps: steps,
      state: initial_state,
      from: nil
    }
  end

  @spec init(__MODULE__.t(), GenServer.from(), dispatch()) :: __MODULE__.t()
  def init(%__MODULE__{} = protocol, from, dispatch) do
    advance(%{protocol | from: from}, dispatch)
  end

  defp advance(%__MODULE__{steps: []} = protocol, _dispatch), do: protocol
  defp advance(%__MODULE__{steps: [{:await, _fun} | _rest]} = protocol, _dispatch), do: protocol

  defp advance(%__MODULE__{steps: [{:call, fun} | rest], state: state} = protocol, dispatch) do
    state = fun.(state, dispatch)
    advance(%{protocol | steps: rest, state: state}, dispatch)
  end

  defp advance(
         %__MODULE__{steps: [{:reply, fun} | rest], state: state, from: from} = protocol,
         dispatch
       ) do
    GenServer.reply(from, fun.(state))
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
    end
  end

  @spec finished?(__MODULE__.t()) :: boolean()
  def finished?(%__MODULE__{steps: []}), do: true
  def finished?(%__MODULE__{}), do: false
end
