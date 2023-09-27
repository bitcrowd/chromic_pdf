# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.Browser.SessionPool do
  @moduledoc false

  @behaviour NimblePool

  require Logger
  alias ChromicPDF.Browser.ExecutionError

  @type session :: any()

  @type pool_state :: %{
          init_worker: (() -> session()),
          terminate_worker: (session() -> any()),
          max_uses: non_neg_integer()
        }

  @type worker_state :: %{
          session: session(),
          uses: non_neg_integer()
        }

  @type checkout_option :: {:skip_session_use_count, boolean()} | {:timeout, non_neg_integer()}
  @type checkout_result :: any()

  @spec child_spec({atom(), keyword()}) :: Supervisor.child_spec()
  def child_spec({id, opts}) do
    %{
      id: {__MODULE__, id},
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts) do
    {pool_size, opts} = Keyword.pop!(opts, :pool_size)

    NimblePool.start_link(worker: {__MODULE__, Map.new(opts)}, pool_size: pool_size)
  end

  @spec checkout!(pid, [checkout_option], (session -> checkout_result)) :: checkout_result
  def checkout!(pid, opts, fun) do
    command =
      if Keyword.fetch!(opts, :skip_session_use_count) do
        :checkout
      else
        :checkout_and_count
      end

    timeout = Keyword.fetch!(opts, :timeout)

    try do
      NimblePool.checkout!(
        pid,
        command,
        fn _, {_pool_state, session} -> {fun.(session), :ok} end,
        timeout
      )
    catch
      :exit, {:timeout, _} ->
        raise(ExecutionError, """
        Caught EXIT signal from NimblePool.checkout!/4

              ** (EXIT) time out

        This means that your operation was unable to acquire a worker from the pool
        within #{timeout}ms, as all workers are currently occupied.

        Two scenarios where this may happen:

        1) You suffer from this error at boot time or in your CI. For instance,
           you're running PDF printing tests in CI and occasionally the first of these test
           fails. This may be caused by Chrome being delayed by initialization tasks when
           it is first launched.

           See ChromicPDF.warm_up/1 for a possible mitigation.

        2) You're experiencing this error randomly under load. This would indicate that
           the number of concurrent print jobs exceeds the total number of workers in
           the pool, so that all workers are occupied.

           To fix this, you need to increase your resources, e.g. by increasing the number
           of workers with the `session_pool: [size: ...]` option.

        Please also consult the session pool concurrency section in the documentation.
        """)
    end
  end

  # ------------ Callbacks -----------

  @impl NimblePool
  def init_worker(pool_state) do
    {:async, fn -> do_init_worker(pool_state) end, pool_state}
  end

  defp do_init_worker(%{init_worker: init_worker}) do
    %{session: init_worker.(), uses: 0}
  end

  @impl NimblePool
  def handle_checkout(:checkout_and_count, from, worker_state, pool_state) do
    handle_checkout(:checkout, from, increment_uses_count(worker_state), pool_state)
  end

  def handle_checkout(:checkout, _from, worker_state, pool_state) do
    {:ok, {pool_state, worker_state.session}, worker_state, pool_state}
  end

  defp increment_uses_count(%{uses: uses} = worker_state) do
    %{worker_state | uses: uses + 1}
  end

  @impl NimblePool
  def handle_checkin(:ok, _from, worker_state, pool_state) do
    if worker_state.uses >= pool_state.max_uses do
      {:remove, :max_uses_reached, pool_state}
    else
      {:ok, worker_state, pool_state}
    end
  end

  @impl NimblePool
  # Reasons we want to gracefully clean up the target in the Browser:
  # - max_uses_reached, our own mechanism for keeping memory bloat in check
  # - error, when an exception is raised in the Channel
  # - DOWN, client link is broken (when client process is terminated externally)
  def terminate_worker(reason, worker_state, pool_state)
      when reason in [:max_uses_reached, :error, :DOWN] do
    if reason == :DOWN do
      Logger.warning("""
      ChromicPDF received a :DOWN message from the process that called `print_to_pdf/2`!

      This means that the process was terminated externally. For instance, your HTTP server
      may have terminated your request after it took too long.
      """)
    end

    Task.async(fn ->
      pool_state.terminate_worker.(worker_state.session)
    end)

    {:ok, pool_state}
  end

  # We do not put in the effort to clean up individual targets shortly before we terminate the
  # external process.
  def terminate_worker(:shutdown, _worker_state, pool_state) do
    {:ok, pool_state}
  end

  # Unexpected other terminate reasons: :timeout | :throw | :exit
end
