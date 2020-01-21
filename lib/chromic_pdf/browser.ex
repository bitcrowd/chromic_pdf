defmodule ChromicPDF.Browser do
  @moduledoc false

  use GenServer
  require Logger
  alias ChromicPDF.{BrowserProtocol, Connection}

  @type browser :: pid() | atom()
  @type session_id :: binary()

  # ------------- API ----------------

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(args) do
    name =
      args
      |> Keyword.fetch!(:chromic)
      |> server_name()

    GenServer.start_link(__MODULE__, nil, name: name)
  end

  @spec server_name(atom()) :: atom()
  def server_name(chromic) do
    Module.concat(chromic, :Browser)
  end

  @spec spawn_session(browser()) :: {:ok, session_id()}
  # This call will trigger the creation of a new target in the running
  # chrome instance. Will block until the target has been attached to.
  # Returns the session_id.
  def spawn_session(pid) do
    GenServer.call(pid, :spawn_session)
  end

  @spec send_session_msg(browser(), session_id(), msg :: binary()) :: :ok
  # Forwards a message from a Session to Chrome.
  def send_session_msg(pid, session_id, msg) do
    GenServer.cast(pid, {:send_session_msg, session_id, msg})
  end

  # ------------ Server --------------

  @impl true
  def init(_) do
    {:ok, conn_pid} = Connection.start_link(self())
    {:ok, protocol_state_pid} = BrowserProtocol.start_link()

    state = %{
      connection: conn_pid,
      sessions: %{},
      pending_sessions: [],
      protocol_state: protocol_state_pid
    }

    {:ok, state}
  end

  @impl true
  def handle_call(:spawn_session, from, state) do
    BrowserProtocol.spawn_session(state.protocol_state)
    {:noreply, %{state | pending_sessions: [from | state.pending_sessions]}}
  end

  @impl true
  def handle_cast({:send_session_msg, session_id, msg}, state) do
    BrowserProtocol.send_session_msg(state.protocol_state, session_id, msg)
    {:noreply, state}
  end

  @impl true
  def handle_info({:chrome_msg_in, msg}, state) do
    BrowserProtocol.handle_chrome_msg_in(state.protocol_state, msg)
    {:noreply, state}
  end

  def handle_info({:chrome_msg_out, msg}, state) do
    Connection.send_msg(state.connection, msg)
    {:noreply, state}
  end

  def handle_info({:session_msg_out, session_id, msg}, state) do
    case Map.get(state.sessions, session_id) do
      nil -> Logger.warn("received message for unknown session_id")
      session_pid -> send(session_pid, {:chrome_msg_in, msg})
    end

    {:noreply, state}
  end

  def handle_info({:session_spawned, session_id}, state) do
    [from | rest] = state.pending_sessions

    # Inform waiting Session about session_id.
    GenServer.reply(from, {:ok, session_id})

    {pid, _ref} = from

    new_state =
      state
      |> put_in([:sessions, session_id], pid)
      |> Map.put(:pending_sessions, rest)

    {:noreply, new_state}
  end
end
