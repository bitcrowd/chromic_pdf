defmodule ChromicPDF.Browser.Channel do
  @moduledoc false

  use GenServer
  alias ChromicPDF.{Connection, Protocol}

  @enforce_keys [:dispatch, :protocols]
  defstruct [:dispatch, :protocols]

  @type t :: %__MODULE__{dispatch: Protocol.dispatch(), protocols: [Protocol.t()]}

  # ------------- API ----------------

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @spec run_protocol(pid(), Protocol.t(), timeout()) :: {:ok, any()} | {:error, term()}
  def run_protocol(pid, %Protocol{} = protocol, timeout) do
    GenServer.call(pid, {:run_protocol, protocol}, timeout)
  catch
    :exit, {:timeout, {GenServer, :call, [_pid, {:run_protocol, _protocol}, _timeout]}} ->
      raise("""
      Timeout in Channel.run_protocol/3!

      The underlying GenServer.call/3 exited with a timeout. This happens when the browser was
      not able to complete the current operation (= PDF print job) within the configured
      #{timeout} milliseconds.

      If you are printing large PDFs and expect long processing times, please consult the
      documentation for the `timeout` option of the session pool.

      If you are *not* printing large PDFs but your print jobs still time out, this is likely a
      bug in ChromicPDF. Please open an issue on the issue tracker.
      """)
  end

  # ----------- Callbacks ------------

  @impl GenServer
  def init(args) do
    {:ok, conn} = Connection.start_link(self(), args)

    dispatch = fn call ->
      Connection.dispatch_call(conn, call)
    end

    {:ok, %__MODULE__{dispatch: dispatch, protocols: []}}
  end

  @impl GenServer
  # Starts protocol processing, asynchronously sends result message when done.
  def handle_call(
        {:run_protocol, protocol},
        from,
        %__MODULE__{dispatch: dispatch, protocols: protocols} = state
      ) do
    protocol = Protocol.init(protocol, &GenServer.reply(from, &1), dispatch)

    {:noreply, update_protocols(state, [protocol | protocols])}
  end

  @impl GenServer
  # Data packets coming in from connection.
  def handle_info({:msg_in, msg}, %__MODULE__{dispatch: dispatch, protocols: protocols} = state) do
    protocols = Enum.map(protocols, &Protocol.run(&1, msg, dispatch))

    {:noreply, update_protocols(state, protocols)}
  end

  defp update_protocols(state, protocols) do
    %{state | protocols: Enum.reject(protocols, &Protocol.finished?(&1))}
  end
end
