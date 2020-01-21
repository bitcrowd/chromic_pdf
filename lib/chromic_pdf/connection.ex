defmodule ChromicPDF.Connection do
  @moduledoc false

  # A running Chrome instance.
  #
  # ## Setup
  #
  # Chrome is started with the "--remote-debugging-pipe" switch
  # and its FD 3 & 4 are redirected to and from stdin and stdout.
  # stderr is silently discarded.
  #
  # ### Receiving messages.
  #
  # Parent process will receive `{:chrome_msg_in, data}` tuples.
  #
  # ### Sending messages
  #
  # See `send_msg/2`.

  use GenServer, shutdown: 10_000
  require Logger

  # ------------- API ----------------

  @spec start_link(pid()) :: GenServer.on_start()
  def start_link(parent_pid) do
    GenServer.start_link(__MODULE__, parent_pid)
  end

  @spec send_msg(pid(), binary()) :: :ok
  def send_msg(pid, msg) do
    GenServer.cast(pid, {:send_msg, msg})
  end

  # ------------ Server --------------

  @chrome_bin "\"/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome\""
  @chrome_cmd "#{@chrome_bin} --headless --disable-gpu --remote-debugging-pipe 2>/dev/null 3<&0 4>&1"

  @impl true
  def init(parent_pid) do
    {:ok, port, os_pid} = spawn_chrome()

    state = %{
      parent_pid: parent_pid,
      port: port,
      os_pid: os_pid,
      data: []
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:send_msg, msg}, state) do
    send(state.port, {self(), {:command, msg <> "\0"}})

    {:noreply, state}
  end

  @impl true
  # Message from chrome on its stdout through the port.
  def handle_info({_port, {:data, data}}, state) do
    new_state =
      data
      |> String.split("\0")
      |> handle_chunks(state)

    {:noreply, new_state}
  end

  # Message triggered by Port.monitor/1.
  def handle_info({:DOWN, _ref, :port, _port, _exit_state}, state) do
    Logger.warn("chrome (pid: #{state.os_pid}) stopped unexpectedly")
    {:stop, :chrome_has_crashed, state}
  end

  @impl true
  # Called on process termination.
  def terminate(_reason, %{port: port}) do
    if Port.info(port), do: Port.close(port)
  end

  defp handle_chunks([blob], state), do: %{state | data: [blob | state.data]}
  defp handle_chunks([blob, ""], state), do: handle_data(%{state | data: [blob | state.data]})

  defp handle_chunks([blob | rest], state),
    do: handle_chunks(rest, handle_data(%{state | data: [blob | state.data]}))

  defp handle_data(state) do
    msg =
      state.data
      |> Enum.reverse()
      |> Enum.join()

    send(state.parent_pid, {:chrome_msg_in, msg})

    %{state | data: []}
  end

  defp spawn_chrome do
    port = Port.open({:spawn, @chrome_cmd}, [:binary])
    Port.monitor(port)

    os_pid = port |> Port.info() |> Keyword.get(:os_pid)
    Logger.info("chrome started (pid: #{os_pid})")

    {:ok, port, os_pid}
  end
end
