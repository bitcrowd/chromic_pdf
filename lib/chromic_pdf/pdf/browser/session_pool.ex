# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.Browser.SessionPool do
  @moduledoc false

  @behaviour NimblePool

  require Logger
  import ChromicPDF.Utils, only: [default_pool_size: 0]
  alias ChromicPDF.Browser
  alias ChromicPDF.Browser.{Channel, ExecutionError}
  alias ChromicPDF.{CloseTarget, SpawnSession}

  @default_init_timeout 5000
  @default_timeout 5000
  @checkout_timeout 5000
  @close_timeout 1000
  @default_max_session_uses 1000

  @type pool_state :: %{
          browser: pid(),
          args: keyword()
        }

  @type worker_state :: %{
          session_id: binary(),
          target_id: binary(),
          uses: non_neg_integer()
        }

  # ------------- API ----------------

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(args) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [self(), args]}
    }
  end

  @spec start_link(pid(), Keyword.t()) :: GenServer.on_start()
  def start_link(browser_pid, args) do
    NimblePool.start_link(
      worker: {__MODULE__, {browser_pid, args}},
      pool_size: pool_size(args)
    )
  end

  defp pool_size(args) do
    get_in(args, [:session_pool, :size]) || default_pool_size()
  end

  @spec run_protocol(pid(), module(), keyword()) :: {:ok, any()} | {:error, term()}
  def run_protocol(pid, protocol_mod, params) do
    NimblePool.checkout!(
      pid,
      command(params),
      fn _, {pool_state, session} ->
        do_run_protocol(protocol_mod, params, pool_state, session)
      end,
      @checkout_timeout
    )
  catch
    :exit, {:timeout, _} ->
      raise(ExecutionError, """
      Caught EXIT signal from NimblePool.checkout!/4

            ** (EXIT) time out

      This means that your operation was unable to acquire a worker from the pool
      within #{@checkout_timeout}ms, as all workers are currently occupied.

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

         However, please be aware that while ChromicPDF (by virtue of the underlying
         NimblePool worker pool) does perform simple queueing of worker checkouts,
         it is not suitable as a proper job queue. If you expect to peaks in your load
         leading to a high level of concurrent use of your PDF printing component,
         a job queue like Oban will provide a better experience.

      Please also consult the worker pool section in the documentation.
      """)
  end

  defp command(params) do
    if params[:skip_session_use_count] do
      :checkout
    else
      :checkout_and_count
    end
  end

  defp do_run_protocol(protocol_mod, params, %{browser: browser, args: args}, %{
         session_id: session_id
       }) do
    protocol = protocol_mod.new(session_id, Keyword.merge(args, params))

    result =
      browser
      |> Browser.channel()
      |> Channel.run_protocol(protocol, timeout(args))

    {result, :ok}
  end

  # ------------ Callbacks -----------

  @impl NimblePool
  def init_pool({browser, args}) do
    args =
      args
      |> Keyword.put_new(:offline, false)
      |> Keyword.put_new(:ignore_certificate_errors, false)
      |> Keyword.put_new(:unhandled_runtime_exceptions, :log)

    {:ok, %{browser: browser, args: args}}
  end

  defp timeout(args) do
    get_in(args, [:session_pool, :timeout]) || @default_timeout
  end

  defp init_timeout(args) do
    get_in(args, [:session_pool, :init_timeout]) || @default_init_timeout
  end

  defp max_session_uses(args) do
    Keyword.get(args, :max_session_uses, @default_max_session_uses)
  end

  @impl NimblePool
  def init_worker(pool_state) do
    {:async, fn -> do_init_worker(pool_state) end, pool_state}
  end

  defp do_init_worker(%{browser: browser, args: args}) do
    {:ok, %{"sessionId" => sid, "targetId" => tid}} =
      browser
      |> Browser.channel()
      |> Channel.run_protocol(SpawnSession.new(args), init_timeout(args))

    %{session: %{session_id: sid, target_id: tid}, uses: 0}
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
    if worker_state.uses >= max_session_uses(pool_state.args) do
      {:remove, :max_session_uses_reached, pool_state}
    else
      {:ok, worker_state, pool_state}
    end
  end

  @impl NimblePool
  # Reasons we want to gracefully clean up the target in the Browser:
  # - max_session_uses_reached, our own mechanism for keeping memory bloat in check
  # - error, when an exception is raised in the Channel
  # - DOWN, client link is broken (when client process is terminated externally)
  def terminate_worker(reason, worker_state, pool_state)
      when reason in [:max_session_uses_reached, :error, :DOWN] do
    if reason == :DOWN do
      Logger.warn("""
      ChromicPDF received a :DOWN message from the process that called `print_to_pdf/2`!

      This means that the process was terminated externally. For instance, your HTTP server
      may have terminated your request after it took too long.
      """)
    end

    Task.async(fn ->
      protocol = CloseTarget.new(targetId: worker_state.session.target_id)

      {:ok, true} =
        pool_state.browser
        |> Browser.channel()
        |> Channel.run_protocol(protocol, @close_timeout)
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
