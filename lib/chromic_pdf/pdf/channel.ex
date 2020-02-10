defmodule ChromicPDF.Channel do
  @moduledoc false

  alias ChromicPDF.{CallCount, Protocol}

  # ---------- Behaviour -------------

  @type upstream :: (binary() -> any())
  @type protocol :: %{mod: module(), state: Protocol.state()}

  @type state :: %{
          protocols: [protocol()],
          call_count: pid(),
          upstream: upstream()
        }

  @callback init_upstream(args :: any()) :: upstream()

  # ------------- API ----------------

  @spec start_protocol(atom() | pid(), module(), any()) :: any()
  def start_protocol(pid, mod, params \\ nil) do
    GenServer.call(pid, {:start_protocol, mod, params})
  end

  @spec send_call(atom() | pid(), Protocol.call()) :: :ok
  def send_call(pid, call) do
    GenServer.cast(pid, {:dispatch, call})
  end

  # ----------- Template -------------

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
        {:noreply, Channel.run_protocols(data, state)}
      end

      @impl GenServer
      def handle_call({:start_protocol, mod, params}, from, state) do
        case Channel.init_protocol(mod, params, from, state) do
          {state, response} -> {:reply, response, state}
          state -> {:noreply, state}
        end
      end

      @impl GenServer
      def handle_cast({:dispatch, call}, state) do
        Channel.dispatch(call, state)
        {:noreply, state}
      end
    end
  end

  # --------- Implementation ---------

  @spec init_state(upstream()) :: state()
  def init_state(upstream) do
    {:ok, call_count} = CallCount.start_link()

    %{
      protocols: [],
      call_count: call_count,
      upstream: upstream
    }
  end

  @spec init_protocol(module(), any(), GenServer.from(), state()) :: state() | {state(), any()}
  def init_protocol(mod, params, from, %{protocols: protocols} = state) do
    case mod.init(from, params, &dispatch(&1, state)) do
      {:ok, protocol_state} ->
        %{state | protocols: [%{mod: mod, state: protocol_state} | protocols]}

      {:done, response} ->
        {state, response}
    end
  end

  @spec run_protocols(data :: binary(), state()) :: state()
  def run_protocols(data, %{protocols: protocols} = state) do
    updated_protocols =
      data
      |> Protocol.decode()
      |> run_protocols_until_handled(protocols, [], &dispatch(&1, state))

    %{state | protocols: updated_protocols}
  end

  # Inspect here if you want to see unhandled messages.
  #  defp run_protocols_until_handled(msg, [], protocols, _dispatcher) do
  #    IO.inspect(msg, label: "unhandled message")
  #    protocols
  #  end

  defp run_protocols_until_handled(_msg, [], protocols, _dispatcher), do: protocols

  defp run_protocols_until_handled(msg, [protocol | protocols], prev, dispatcher) do
    case protocol.mod.handle_msg(msg, protocol.state, dispatcher) do
      :ignore ->
        run_protocols_until_handled(msg, protocols, [protocol | prev], dispatcher)

      :done ->
        prev ++ protocols

      {:ok, new_state} ->
        prev ++ [%{protocol | state: new_state}] ++ protocols
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
end
