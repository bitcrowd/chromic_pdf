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

  @spec server_name(atom()) :: atom()
  def server_name(chromic) do
    Module.concat(chromic, :Browser)
  end

  @spec run(browser(), Protocol.t()) :: {:ok, any()}
  def run(browser, protocol) do
    GenServer.call(browser, {:run, protocol})
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
  def handle_call({:run, protocol}, from, %{dispatch: dispatch, protocols: protocols} = state) do
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
