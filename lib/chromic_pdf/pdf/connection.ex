# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.Connection do
  @moduledoc false

  use GenServer
  alias ChromicPDF.Connection.{ConnectionLostError, JsonRPC, Tokenizer}

  defmodule ChromeRunner do
    @moduledoc false

    @callback spawn(keyword()) :: {:ok, port()}
    @callback send_msg(port(), msg :: binary()) :: :ok
  end

  @chrome Application.compile_env(:chromic_pdf, :chrome, ChromicPDF.ChromeRunner)

  @type state :: %{
          port: port(),
          parent_pid: pid(),
          tokenizer: Tokenizer.t(),
          next_call_id: pos_integer()
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

  @spec port_info(pid) :: keyword()
  def port_info(pid) do
    GenServer.call(pid, :port_info)
  end

  # ------------ Server --------------

  @impl GenServer
  def init({parent_pid, opts}) do
    {:ok, port} = spawn_chrome(opts)

    Process.flag(:trap_exit, true)

    state = %{
      port: port,
      parent_pid: parent_pid,
      tokenizer: Tokenizer.init(),
      next_call_id: 1
    }

    {:ok, state}
  end

  defp spawn_chrome(opts) do
    opts
    |> Keyword.take([:chrome_args, :discard_stderr, :no_sandbox, :chrome_executable])
    |> @chrome.spawn()
  end

  @impl GenServer
  def handle_call({:dispatch_call, call}, _from, %{port: port, next_call_id: call_id} = state) do
    @chrome.send_msg(port, JsonRPC.encode(call, call_id))

    {:reply, call_id, %{state | next_call_id: call_id + 1}}
  end

  def handle_call(:port_info, _from, %{port: port} = state) do
    {:reply, Port.info(port), state}
  end

  @impl GenServer
  # Message from Chrome through the port.
  def handle_info({_port, {:data, data}}, state) do
    {msgs, tokenizer} = Tokenizer.tokenize(data, state.tokenizer)

    for msg <- msgs do
      send(state.parent_pid, {:chrome_message, JsonRPC.decode(msg)})
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
    {:stop, :connection_lost, state}
  end

  @impl GenServer
  def terminate(:normal, _state), do: :ok

  def terminate(:connection_lost, _state) do
    raise(ConnectionLostError, """
    Chrome has stopped or was terminated by an external program.

    If this happened while you were printing a PDF, this may be a problem with Chrome itelf.
    If this happens at startup and you are running inside a Docker container with a Linux-based
    image, please see the "Chrome Sandbox in Docker containers" section of the documentation.

    Either way, to see Chrome's error output, configure ChromicPDF with the option

        discard_stderr: false
    """)
  end

  def terminate(:shutdown, %{port: port, next_call_id: call_id}) do
    # Graceful shutdown: Dispatch the Browser.close call to Chrome which will cause it to detach
    # all debugging sessions and close the port.
    @chrome.send_msg(port, JsonRPC.encode({"Browser.close", %{}}, call_id))

    # We can't enter the GenServer loop from here, so we need to manually receive the message
    # about the port going down. In case Chrome takes longer than the configured supervision
    # shutdown time, we'll receive a :brutal_kill and exit immediately, so no need for a timeout.
    receive do
      {:DOWN, _ref, :port, _port, _exit_state} ->
        :ok
    end
  end
end
