defmodule ChromicPDF.Browser.Channel do
  @moduledoc false

  use GenServer
  alias ChromicPDF.{CloseTarget, Connection, Protocol, SpawnSession}

  @enforce_keys [:dispatch, :spawn_protocol, :protocols, :timeout]
  defstruct [:dispatch, :spawn_protocol, :protocols, :timeout]

  @type t :: %__MODULE__{
          dispatch: Protocol.dispatch(),
          spawn_protocol: Protocol.t(),
          protocols: [Protocol.t()]
        }

  @type session :: %{
          session_id: binary(),
          target_id: binary()
        }

  @default_timeout 5000
  @session_operation_timeout 1000

  # ------------- API ----------------

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @spec spawn_session(pid()) :: session()
  def spawn_session(pid) do
    {:ok, %{"sessionId" => sid, "targetId" => tid}} =
      GenServer.call(pid, :spawn_session, @session_operation_timeout)

    %{session_id: sid, target_id: tid}
  end

  @spec close_session(pid(), session()) :: :ok
  def close_session(pid, %{target_id: tid}) do
    protocol = CloseTarget.new(targetId: tid)

    {:ok, _} = GenServer.call(pid, {:run_protocol, protocol}, @session_operation_timeout)

    :ok
  end

  @spec run_protocol(pid(), session(), protocol_mod :: module(), params :: keyword()) ::
          {:ok, any()} | {:error, term()}
  def run_protocol(pid, session, protocol_mod, params) do
    timeout = GenServer.call(pid, :timeout)

    run_protocol(pid, session, protocol_mod, params, timeout)
  end

  @spec run_protocol(pid(), session(), protocol_mod :: module(), params :: keyword(), timeout()) ::
          {:ok, any()} | {:error, term()}
  def run_protocol(pid, %{session_id: sid}, protocol_mod, params, timeout) do
    protocol = protocol_mod.new(sid, params)

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

    {:ok,
     %__MODULE__{
       dispatch: dispatch,
       spawn_protocol: spawn_protocol(args),
       protocols: [],
       timeout: timeout(args)
     }}
  end

  defp timeout(args) do
    # TODO: deprecate this option in favour of a better suited one?
    get_in(args, [:session_pool, :timeout]) || @default_timeout
  end

  @impl GenServer
  # Starts the spawn protocol.
  def handle_call(:spawn_session, from, %__MODULE__{spawn_protocol: spawn_protocol} = state) do
    {:noreply, init_protocol(spawn_protocol, from, state)}
  end

  # Starts protocol processing, asynchronously sends result message when done.
  def handle_call({:run_protocol, protocol}, from, %__MODULE__{} = state) do
    {:noreply, init_protocol(protocol, from, state)}
  end

  # Fetches the default timeout from the state.
  def handle_call(:timeout, _from, %__MODULE__{timeout: timeout} = state) do
    {:reply, timeout, state}
  end

  @impl GenServer
  # Data packets coming in from connection.
  def handle_info({:msg_in, msg}, %__MODULE__{dispatch: dispatch, protocols: protocols} = state) do
    protocols = Enum.map(protocols, &Protocol.run(&1, msg, dispatch))

    {:noreply, update_protocols(state, protocols)}
  end

  defp spawn_protocol(args) do
    args
    |> Keyword.put_new(:offline, false)
    |> Keyword.put_new(:ignore_certificate_errors, false)
    |> SpawnSession.new()
  end

  defp init_protocol(protocol, from, %{dispatch: dispatch, protocols: protocols} = state) do
    protocol = Protocol.init(protocol, &GenServer.reply(from, &1), dispatch)

    update_protocols(state, [protocol | protocols])
  end

  defp update_protocols(state, protocols) do
    %{state | protocols: Enum.reject(protocols, &Protocol.finished?(&1))}
  end
end
