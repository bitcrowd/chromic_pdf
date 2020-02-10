defmodule ChromicPDF.Connection do
  @moduledoc false

  use GenServer, shutdown: 10_000

  @chrome Application.get_env(:chromic_pdf, :chrome, ChromicPDF.ChromeImpl)

  # ------------- API ----------------

  @spec start_link(pid(), keyword()) :: GenServer.on_start()
  def start_link(parent_pid, opts) do
    GenServer.start_link(__MODULE__, {parent_pid, opts})
  end

  @spec send_msg(pid(), binary()) :: :ok
  def send_msg(pid, msg) do
    GenServer.cast(pid, {:send_msg, msg})
  end

  # ------------ Server --------------

  @impl true
  def init({parent_pid, opts}) do
    chrome_opts = Keyword.take(opts, [:no_sandbox])
    {:ok, port} = @chrome.spawn(chrome_opts)

    state = %{
      parent_pid: parent_pid,
      port: port,
      data: []
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:send_msg, msg}, state) do
    @chrome.send_msg(state.port, msg)
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
    {:stop, :chrome_has_crashed, state}
  end

  @impl true
  # Called on process termination.
  def terminate(_reason, %{port: port}) do
    @chrome.stop(port)
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

    send(state.parent_pid, {:msg_in, msg})

    %{state | data: []}
  end
end
