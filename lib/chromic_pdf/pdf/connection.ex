defmodule ChromicPDF.Connection do
  @moduledoc false

  use GenServer
  alias ChromicPDF.Connection.{Dispatcher, JsonRPC, Tokenizer}

  @chrome Application.compile_env(:chromic_pdf, :chrome, ChromicPDF.ChromeImpl)

  @type state :: %{
          parent_pid: pid(),
          tokenizer: Tokenizer.t(),
          dispatcher: Dispatcher.t()
        }

  # ------------- API ----------------

  @spec start_link(pid(), keyword()) :: GenServer.on_start()
  def start_link(parent_pid, opts) do
    GenServer.start_link(__MODULE__, {parent_pid, opts})
  end

  @spec dispatch_call(pid(), binary()) :: :ok
  def dispatch_call(pid, msg) do
    GenServer.call(pid, {:dispatch_call, msg})
  end

  # ------------ Server --------------

  @impl GenServer
  def init({parent_pid, opts}) do
    {:ok, port} = spawn_chrome(opts)

    Process.flag(:trap_exit, true)

    state = %{
      parent_pid: parent_pid,
      tokenizer: Tokenizer.init(),
      dispatcher: Dispatcher.init(port)
    }

    {:ok, state}
  end

  defp spawn_chrome(opts) do
    opts
    |> Keyword.take([:discard_stderr, :no_sandbox])
    |> @chrome.spawn()
  end

  @impl GenServer
  def handle_call({:dispatch_call, call}, _from, state) do
    {reply, dispatcher} = Dispatcher.dispatch(state.dispatcher, call)

    {:reply, reply, %{state | dispatcher: dispatcher}}
  end

  @impl GenServer
  # Message from Chrome through the port.
  def handle_info({_port, {:data, data}}, state) do
    {msgs, tokenizer} = Tokenizer.tokenize(data, state.tokenizer)

    for msg <- msgs do
      send(state.parent_pid, {:msg_in, JsonRPC.decode(msg)})
    end

    {:noreply, %{state | tokenizer: tokenizer}}
  end

  # Message triggered by Port.monitor/1.
  # This is unlikely to happen outside terminate/2 (:shutdown).
  def handle_info({:DOWN, _ref, :port, _port, _exit_state}, state) do
    {:noreply, state}
  end

  # EXIT signal from port process since we trap signals.
  def handle_info({:EXIT, _port, _reason}, state) do
    # Chrome has crashed or was terminated externally.
    {:stop, :connection_terminated, state}
  end

  @impl GenServer
  def terminate(:normal, _state), do: :ok
  def terminate(:connection_terminated, _state), do: :ok

  def terminate(:shutdown, state) do
    # Graceful shutdown: Dispatch the Browser.close call to Chrome which will cause it to detach
    # all debugging sessions and close the port.
    Dispatcher.dispatch(state.dispatcher, {"Browser.close", %{}})

    # We can't enter the GenServer loop from here, so we need to manually receive the message
    # about the port going down. In case Chrome takes longer than the configured supervision
    # shutdown time, we'll receive a :brutal_kill and exit immediately, so no need for a timeout.
    receive do
      {:DOWN, _ref, :port, _port, _exit_state} ->
        :ok
    end
  end
end
