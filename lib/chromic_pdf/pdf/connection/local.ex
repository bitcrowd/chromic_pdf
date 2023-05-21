# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.Connection.Local do
  @moduledoc false

  use ChromicPDF.Connection
  alias ChromicPDF.ChromeRunner
  alias ChromicPDF.Connection.{ConnectionLostError, Tokenizer}

  @type state :: %{
          port: port(),
          parent_pid: pid(),
          tokenizer: Tokenizer.t()
        }

  @impl ChromicPDF.Connection
  def handle_init(opts) do
    port =
      opts
      |> Keyword.take([:chrome_args, :discard_stderr, :no_sandbox, :chrome_executable])
      |> ChromeRunner.port_open()

    Port.monitor(port)

    {:ok, %{port: port, tokenizer: Tokenizer.init()}}
  end

  @impl ChromicPDF.Connection
  def handle_msg(msg, %{port: port}) do
    send(port, {self(), {:command, msg <> "\0"}})

    :ok
  end

  @impl GenServer
  def handle_info({_port, {:data, data}}, %{tokenizer: tokenizer} = state) do
    {msgs, tokenizer} = Tokenizer.tokenize(data, tokenizer)

    for msg <- msgs do
      send_msg_to_channel(msg, state)
    end

    {:noreply, %{state | tokenizer: tokenizer}}
  end

  # Message triggered by Port.monitor/1.
  # Port is down, likely due to the external process having been killed.
  def handle_info({:DOWN, _ref, :port, _port, _exit_state}, _state) do
    raise(ConnectionLostError, """
    Chrome has stopped or was terminated by an external program.

    If this happened while you were printing a PDF, this may be a problem with Chrome itelf.
    If this happens at startup and you are running inside a Docker container with a Linux-based
    image, please see the "Chrome Sandbox in Docker containers" section of the documentation.

    Either way, to see Chrome's error output, configure ChromicPDF with the option

        discard_stderr: false
    """)
  end

  @spec port_info(pid()) :: {atom(), term()} | nil
  def port_info(pid) do
    GenServer.call(pid, :port_info)
  end

  @impl GenServer
  def handle_call(:port_info, _from, %{port: port} = state) do
    {:reply, Port.info(port), state}
  end
end
