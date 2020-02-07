defmodule ChromicPDF.Browser do
  @moduledoc false

  use ChromicPDF.Channel

  # credo:disable-for-next-line Credo.Check.Readability.AliasOrder
  alias ChromicPDF.{Connection, SpawnSession, SendMessageToTarget}

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
    Channel.start_protocol(pid, SpawnSession)
  end

  @spec send_session_msg(browser(), session_id(), msg :: binary()) :: :ok
  # Sends a message in a `sendMessageToTarget` envelope to Chrome.
  # Does not wait for response.
  def send_session_msg(pid, session_id, msg) do
    Channel.start_protocol(pid, SendMessageToTarget, {session_id, msg})
  end

  # ----------- Callbacks ------------

  @impl ChromicPDF.Channel
  def init_upstream(_args) do
    {:ok, conn_pid} = Connection.start_link(self())

    fn msg ->
      Connection.send_msg(conn_pid, msg)
    end
  end
end
