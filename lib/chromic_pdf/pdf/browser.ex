defmodule ChromicPDF.Browser do
  @moduledoc false

  use ChromicPDF.Channel

  # credo:disable-for-next-line Credo.Check.Readability.AliasOrder
  alias ChromicPDF.{Connection, SpawnSession}

  @type browser :: pid() | atom()
  @type session_id :: binary()

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
    Channel.send_call(pid, {
      "Target.sendMessageToTarget",
      %{"message" => msg, "sessionId" => session_id}
    })
  end

  # ----------- Callbacks ------------

  @impl ChromicPDF.Channel
  def init_upstream(args) do
    {:ok, conn_pid} = Connection.start_link(self(), args)

    Process.flag(:trap_exit, true)

    fn msg ->
      Connection.send_msg(conn_pid, msg)
    end
  end

  @impl GenServer
  def terminate(_reason, _state) do
    Channel.send_call(self(), {"Browser.close", %{}})
  end
end
