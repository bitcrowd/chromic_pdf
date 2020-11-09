defmodule ChromicPDF.Browser do
  @moduledoc false

  use GenServer
  alias ChromicPDF.{Connection, Protocol}

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

  @spec run_protocol(atom(), Protocol.t()) :: {:ok, any()} | {:error, term()}
  def run_protocol(chromic, %Protocol{} = protocol) when is_atom(chromic) do
    GenServer.call(server_name(chromic), {:run_protocol, protocol})
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

    dispatch = fn call ->
      Connection.dispatch_call(conn_pid, call)
    end

    {:ok, %{dispatch: dispatch, protocols: []}}
  end

  @impl GenServer
  def handle_call(
        {:run_protocol, protocol},
        from,
        %{dispatch: dispatch, protocols: protocols} = state
      ) do
    protocol = Protocol.init(protocol, &GenServer.reply(from, &1), dispatch)
    {:noreply, update_protocols(state, [protocol | protocols])}
  end

  # Data packets coming in from connection.
  @impl GenServer
  def handle_info({:msg_in, msg}, %{dispatch: dispatch, protocols: protocols} = state) do
    protocols = Enum.map(protocols, &Protocol.run(&1, msg, dispatch))
    {:noreply, update_protocols(state, protocols)}
  end

  defp update_protocols(state, protocols) do
    %{state | protocols: Enum.reject(protocols, &Protocol.finished?(&1))}
  end
end
