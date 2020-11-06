defmodule ChromicPDF.Browser do
  @moduledoc false

  use GenServer
  alias ChromicPDF.{CallCount, Connection, JsonRPC, Protocol}

  @type browser :: pid() | atom()
  @type state :: %{dispatch: Protocol.dispatch(), protocols: [Protocol.t()]}

  # ------------- API ----------------

  def child_spec(args) do
    %{
      id: server_name_from_args(args),
      start: {ChromicPDF.Browser, :start_link, [args]},
      shutdown: 5_000
    }
  end

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: server_name_from_args(args))
  end

  @spec run_protocol(browser(), Protocol.t()) :: {:ok, any()} | {:error, term()}
  def run_protocol(chromic, %Protocol{} = protocol) when is_atom(chromic) do
    GenServer.call(server_name(chromic), {:run_protocol, protocol})
  end

  def run_protocol(browser, %Protocol{} = protocol) when is_pid(browser) do
    GenServer.call(browser, {:run_protocol, protocol})
  end

  defp server_name_from_args(args) do
    args
    |> Keyword.fetch!(:chromic)
    |> server_name()
  end

  defp server_name(chromic) do
    Module.concat(chromic, :Browser)
  end

  # ----------- Callbacks ------------

  @impl GenServer
  def init(args) do
    {:ok, conn_pid} = Connection.start_link(self(), args)
    {:ok, call_count_pid} = CallCount.start_link()

    Process.flag(:trap_exit, true)

    dispatch = fn call ->
      call_id = CallCount.bump(call_count_pid)
      Connection.send_msg(conn_pid, JsonRPC.encode(call, call_id))
      call_id
    end

    {:ok, %{dispatch: dispatch, protocols: []}}
  end

  @impl GenServer
  def terminate(:shutdown, %{dispatch: dispatch}) do
    # Graceful shutdown: Dispatch the Browser.close message to Chrome which will cause it to
    # detach all debugging sessions and close the port.
    dispatch.({"Browser.close", %{}})

    # The Connection process will receive a message about the port termination and forward
    # this to us. In case Chrome takes longer than the configured supervision shutdown time,
    # we'll receive a :brutal_kill and exit immediately, so no need for a timeout here.
    receive do
      {:connection_terminated, _exit_state} -> :ok
    end
  end

  # Called when we return `{:stop, :connection_terminated, _}` from `handle_info/2`.
  def terminate(:connection_terminated, _state), do: :ok

  @impl GenServer
  def handle_call(
        {:run_protocol, protocol},
        from,
        %{dispatch: dispatch, protocols: protocols} = state
      ) do
    protocols = [Protocol.init(protocol, from, dispatch) | protocols]
    {:noreply, update_protocols(state, protocols)}
  end

  # Data packets coming in from connection.
  @impl GenServer
  def handle_info({:msg_in, data}, %{dispatch: dispatch, protocols: protocols} = state) do
    msg = JsonRPC.decode(data)
    protocols = Enum.map(protocols, &Protocol.run(&1, msg, dispatch))
    {:noreply, update_protocols(state, protocols)}
  end

  def handle_info({:connection_terminated, _exit_state}, state) do
    # If we receive this message in this `handle_info/2` clause, it means that we're not
    # performing a graceful shutdown right now and Chrome has either crashed or was closed
    # externally, so let's suicide and let the supervisor restart us.
    {:stop, :connection_terminated, state}
  end

  defp update_protocols(state, protocols) do
    %{state | protocols: Enum.reject(protocols, &Protocol.finished?(&1))}
  end
end
