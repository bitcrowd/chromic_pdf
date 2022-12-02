# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.Browser.Channel do
  @moduledoc false

  use GenServer
  require Logger
  alias ChromicPDF.Browser.ExecutionError
  alias ChromicPDF.{Connection, Protocol}

  # ------------- API ----------------

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @spec run_protocol(pid(), Protocol.t(), timeout()) :: {:ok, any()} | {:error, term()}
  def run_protocol(pid, %Protocol{} = protocol, timeout) do
    GenServer.call(pid, {:run_protocol, protocol, make_ref()}, timeout)
  catch
    :exit, {:timeout, {GenServer, :call, [pid, {:run_protocol, _protocol, ref}, _timeout]}} ->
      raise(ExecutionError, """
      Timeout in Channel.run_protocol/3!

      The underlying GenServer.call/3 exited with a timeout. This happens when the browser was
      not able to complete the current operation (= PDF print job) within the configured
      #{timeout} milliseconds.

      If you are printing large PDFs and expect long processing times, please consult the
      documentation for the `timeout` option of the session pool.

      If you are *not* printing large PDFs but your print jobs still time out, this is likely a
      bug in ChromicPDF. Please open an issue on the issue tracker.

      ---

      Current protocol:

      #{pid |> GenServer.call({:cancel_protocol, ref}) |> inspect(pretty: true)}
      """)
  end

  # ----------- Callbacks ------------

  @impl GenServer
  def init(args) do
    {:ok, conn} = Connection.start_link(self(), args)

    {:ok, %{conn: conn, waitlist: []}}
  end

  # Starts protocol processing, asynchronously sends result message when done.
  @impl GenServer
  def handle_call({:run_protocol, protocol, ref}, from, state) do
    task = %{protocol: protocol, from: from, ref: ref}

    {:noreply, handle_run_protocol(task, state)}
  end

  # Removes protocol from list and sends current state to client.
  @impl GenServer
  def handle_call({:cancel_protocol, ref}, _from, state) do
    {protocol, state} = handle_cancel_protocol(ref, state)

    {:reply, protocol, state}
  end

  # Data packets coming in from connection.
  @impl GenServer
  def handle_info({:chrome_message, msg}, state) do
    warn_on_inspector_crash!(msg)

    {:noreply, handle_chrome_message(msg, state)}
  end

  defp warn_on_inspector_crash!(msg) do
    if match?(%{"method" => "Inspector.targetCrashed"}, msg) do
      Logger.error("""
      ChromicPDF received an 'Inspector.targetCrashed' message.

      This means an active Chrome tab has died and your current operation is going to time out.

      Known causes:

      1) External URLs in <link> tags in the header/footer templates cause Chrome to crash.
      2) Shared memory exhaustion can cause Chrome to crash. Depending on your environment, the
         available shared memory at /dev/shm may be too small for your use-case. This may
         especially affect you if you run ChromicPDF in a container, as, for instance, the
         Docker runtime provides only 64 MB to containers by default.

         Pass --disable-dev-shm-usage as a Chrome flag to use /tmp for this purpose instead
         (via the chrome_args option), or increase the amount of shared memory available to
         the container (see --shm-size for Docker).
      """)
    end
  end

  # -------- Task execution ----------

  # "Runs" the protocol processing until done or await instruction reached.
  defp handle_run_protocol(task, %{conn: conn} = state) do
    case Protocol.run(task.protocol, &Connection.dispatch_call(conn, &1)) do
      {:halt, result} ->
        GenServer.reply(task.from, result)
        state

      {:await, protocol} ->
        push_to_waitlist(state, %{task | protocol: protocol})
    end
  end

  # Removes matching task from waitlist and returns protocol.
  defp handle_cancel_protocol(ref, state) do
    pop_from_waitlist(state, fn task ->
      if task.ref == ref do
        task.protocol
      end
    end)
  end

  # Removes task for which protocol can consume incoming chrome message from waitlist and
  # passes it back to `handle_run_protocol` for further processing and re-enqueueing.
  defp handle_chrome_message(msg, state) do
    case pop_from_waitlist(state, &match_chrome_message(&1, msg)) do
      {nil, state} ->
        state

      {task, state} ->
        handle_run_protocol(task, state)
    end
  end

  # Matches message against single protocol and updates task on match.
  defp match_chrome_message(task, msg) do
    case Protocol.match_chrome_message(task.protocol, msg) do
      :no_match -> false
      {:match, protocol} -> %{task | protocol: protocol}
    end
  end

  # -------- State management --------

  defp push_to_waitlist(%{waitlist: waitlist} = state, task) do
    %{state | waitlist: [task | waitlist]}
  end

  # Pops a value for which predicate is truthy from waitlist, returns predicate result.
  defp pop_from_waitlist(%{waitlist: waitlist} = state, fun) do
    {matched, waitlist} = do_pop_from_waitlist(waitlist, fun, [])
    {matched, %{state | waitlist: waitlist}}
  end

  defp do_pop_from_waitlist([], _fun, acc), do: {nil, acc}

  defp do_pop_from_waitlist([task | rest], fun, acc) do
    if value = fun.(task) do
      {value, rest ++ acc}
    else
      do_pop_from_waitlist(rest, fun, [task | acc])
    end
  end
end
