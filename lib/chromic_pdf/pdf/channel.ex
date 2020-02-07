defmodule ChromicPDF.Channel do
  @moduledoc false

  alias ChromicPDF.{CallCount, Protocol}

  @type upstream :: (binary() -> any())
  @type protocol :: %{mod: module(), state: Protocol.state()}

  @type state :: %{
          protocols: [protocol()],
          call_count: pid(),
          upstream: upstream()
        }

  @callback init_upstream(args :: any()) :: upstream()

  @spec init_state(upstream()) :: state()
  def init_state(upstream) do
    {:ok, call_count} = CallCount.start_link()

    %{
      protocols: [],
      call_count: call_count,
      upstream: upstream
    }
  end

  @spec start_protocol(atom() | pid(), module(), any()) :: any()
  def start_protocol(pid, mod, params \\ nil) do
    GenServer.call(pid, {:start_protocol, mod, params})
  end

  defmacro __using__(_opts) do
    quote do
      use GenServer

      alias ChromicPDF.{Channel, Protocol}

      @behaviour ChromicPDF.Channel

      @impl GenServer
      def init(args) do
        state =
          args
          |> init_upstream()
          |> Channel.init_state()

        {:ok, state}
      end

      @impl GenServer
      def handle_info({:msg_in, data}, %{protocols: protocols} = state) do
        updated_protocols =
          data
          |> Protocol.decode()
          |> Channel.run_protocols(protocols, &Channel.dispatch(&1, state))

        {:noreply, %{state | protocols: updated_protocols}}
      end

      @impl GenServer
      def handle_call({:start_protocol, mod, params}, from, %{protocols: protocols} = state) do
        case mod.init(from, params, &Channel.dispatch(&1, state)) do
          {:ok, protocol_state} ->
            {:noreply, %{state | protocols: [%{mod: mod, state: protocol_state} | protocols]}}

          {:done, response} ->
            {:reply, response, state}
        end
      end
    end
  end

  @spec dispatch(Protocol.call(), state()) :: Protocol.call_id()
  def dispatch(call, state) do
    call_id = CallCount.bump(state.call_count)

    call_id
    |> Protocol.encode(call)
    |> state.upstream.()

    call_id
  end

  @spec run_protocols(Protocol.msg(), [protocol()], Protocol.dispatcher()) :: [protocol()]
  def run_protocols(msg, protocols, dispatcher) do
    do_run_protocols(msg, protocols, [], dispatcher)
  end

  # Inspect here if you want to see unhandled messages.
  defp do_run_protocols(_msg, [], protocols, _dispatcher), do: protocols

  defp do_run_protocols(msg, [protocol | protocols], prev, dispatcher) do
    case protocol.mod.handle_msg(msg, protocol.state, dispatcher) do
      :ignore ->
        do_run_protocols(msg, protocols, [protocol | prev], dispatcher)

      :done ->
        prev ++ protocols

      {:ok, new_state} ->
        prev ++ [%{protocol | state: new_state}] ++ protocols
    end
  end
end
