defmodule ChromicPDF.Browser do
  @moduledoc false

  use GenServer
  alias ChromicPDF.{CallCount, Connection, JsonRPC, Protocol}

  @type browser :: pid() | atom()
  @type state :: %{dispatch: Protocol.dispatch(), protocols: [Protocol.t()]}

  # ------------- API ----------------

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(args) do
    name =
      args
      |> Keyword.fetch!(:chromic)
      |> server_name()

    GenServer.start_link(__MODULE__, args, name: name)
  end

  @spec run_protocol(browser(), Protocol.t()) :: {:ok, any()} | {:error, term()}
  def run_protocol(browser, %Protocol{} = protocol) do
    genserver_call(browser, {:run_protocol, protocol})
  end

  defp server_name(chromic) do
    Module.concat(chromic, :Browser)
  end

  defp genserver_call(chromic, msg) when is_atom(chromic) do
    GenServer.call(server_name(chromic), msg)
  end

  defp genserver_call(browser, msg) when is_pid(browser) do
    GenServer.call(browser, msg)
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
  def terminate(_reason, %{dispatch: dispatch}) do
    dispatch.({"Browser.close", %{}})
  end

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

  defp update_protocols(state, protocols) do
    %{state | protocols: Enum.reject(protocols, &Protocol.finished?(&1))}
  end
end
