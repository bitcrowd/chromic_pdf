defmodule ChromicPDF.Browser.SessionPool do
  @moduledoc false

  @behaviour NimblePool

  import ChromicPDF.Utils, only: [default_pool_size: 0]
  alias ChromicPDF.Browser

  @default_max_session_uses 1000

  @type pool_state :: %{
          browser: pid(),
          max_session_uses: non_neg_integer()
        }

  @type worker_state :: %{
          session: Browser.Channel.session(),
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

  @spec checkout!(pid(), function()) :: any()
  def checkout!(pid, callback) do
    NimblePool.checkout!(pid, :checkout, fn _, session -> {callback.(session), :checkin} end)
  end

  # ------------- Callbacks ----------------

  @impl NimblePool
  @spec init_pool({pid(), keyword()}) :: {:ok, pool_state()}
  def init_pool({browser, args}) do
    {:ok,
     %{
       browser: browser,
       max_session_uses: max_session_uses(args)
     }}
  end

  defp max_session_uses(args) do
    Keyword.get(args, :max_session_uses, @default_max_session_uses)
  end

  @impl NimblePool
  @spec init_worker(pool_state()) :: {:async, (() -> worker_state()), pool_state()}
  def init_worker(%{browser: browser} = pool_state) do
    {:async, fn -> do_init_worker(browser) end, pool_state}
  end

  defp do_init_worker(browser) do
    %{
      session: Browser.spawn_session(browser),
      uses: 0
    }
  end

  @impl NimblePool
  def handle_checkout(:checkout, _from, worker_state, pool_state) do
    # increment use count
    worker_state = %{worker_state | uses: worker_state.uses + 1}

    {:ok, worker_state.session, worker_state, pool_state}
  end

  @impl NimblePool
  def handle_checkin(:checkin, _from, worker_state, pool_state) do
    if worker_state.uses >= pool_state.max_session_uses do
      {:remove, :max_session_uses_reached, pool_state}
    else
      {:ok, worker_state, pool_state}
    end
  end

  @impl NimblePool
  def terminate_worker(:max_session_uses_reached, session, pool_state) do
    Task.async(fn ->
      {:ok, true} = Browser.close_session(pool_state.browser, session)
    end)

    {:ok, pool_state}
  end

  def terminate_worker(_other, _worker_state, pool_state) do
    {:ok, pool_state}
  end
end
