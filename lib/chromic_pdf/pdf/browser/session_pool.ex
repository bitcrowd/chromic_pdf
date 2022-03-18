defmodule ChromicPDF.Browser.SessionPool do
  @moduledoc false

  @behaviour NimblePool

  import ChromicPDF.Utils, only: [default_pool_size: 0]
  alias ChromicPDF.Browser
  alias ChromicPDF.Browser.Channel
  alias ChromicPDF.{CloseTarget, Protocol, SpawnSession}

  @default_init_timeout 5000
  @default_timeout 5000
  @default_max_session_uses 1000

  @type pool_state :: %{
          browser: pid(),
          spawn_protocol: Protocol.t(),
          max_session_uses: non_neg_integer(),
          init_timeout: timeout(),
          timeout: timeout()
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
      command(protocol_mod),
      fn _, {channel, %{session_id: session_id}, timeout} ->
        protocol = protocol_mod.new(session_id, params)
        result = Channel.run_protocol(channel, protocol, timeout)

        {result, :ok}
      end
    )
  end

  defp command(protocol_mod) do
    if protocol_mod.increment_session_use_count?() do
      :checkout_and_count
    else
      :checkout
    end
  end

  # ------------ Callbacks -----------

  @impl NimblePool
  @spec init_pool({pid(), keyword()}) :: {:ok, pool_state()}
  def init_pool({browser, args}) do
    {:ok,
     %{
       browser: browser,
       spawn_protocol: spawn_protocol(args),
       max_session_uses: max_session_uses(args),
       init_timeout: init_timeout(args),
       timeout: timeout(args)
     }}
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

  defp spawn_protocol(args) do
    args
    |> Keyword.put_new(:offline, false)
    |> Keyword.put_new(:ignore_certificate_errors, false)
    |> SpawnSession.new()
  end

  @impl NimblePool
  @spec init_worker(pool_state()) :: {:async, (() -> worker_state()), pool_state()}
  def init_worker(
        %{browser: browser, spawn_protocol: spawn_protocol, init_timeout: init_timeout} =
          pool_state
      ) do
    {:async, fn -> do_init_worker(browser, spawn_protocol, init_timeout) end, pool_state}
  end

  defp do_init_worker(browser, spawn_protocol, timeout) do
    {:ok, %{"sessionId" => sid, "targetId" => tid}} =
      browser
      |> Browser.channel()
      |> Channel.run_protocol(spawn_protocol, timeout)

    %{session_id: sid, target_id: tid, uses: 0}
  end

  @impl NimblePool
  def handle_checkout(:checkout_and_count, from, session, pool_state) do
    handle_checkout(:checkout, from, increment_uses_count(session), pool_state)
  end

  def handle_checkout(:checkout, _from, session, pool_state) do
    client_state = {Browser.channel(pool_state.browser), session, pool_state.timeout}
    {:ok, client_state, session, pool_state}
  end

  defp increment_uses_count(%{uses: uses} = session) do
    %{session | uses: uses + 1}
  end

  @impl NimblePool
  def handle_checkin(:ok, _from, session, pool_state) do
    if session.uses >= pool_state.max_session_uses do
      {:remove, :max_session_uses_reached, pool_state}
    else
      {:ok, session, pool_state}
    end
  end

  @impl NimblePool
  def terminate_worker(:max_session_uses_reached, session, pool_state) do
    Task.async(fn ->
      {:ok, true} =
        pool_state.browser
        |> Browser.channel()
        |> Channel.run_protocol(CloseTarget.new(targetId: session.target_id), @default_timeout)
    end)

    {:ok, pool_state}
  end

  def terminate_worker(_other, _worker_state, pool_state) do
    {:ok, pool_state}
  end
end
