defmodule ChromicPDF.Session do
  @moduledoc false

  use GenServer
  alias ChromicPDF.{Browser, CloseTarget, SpawnSession}

  @default_max_session_uses 1000

  # ------------- API ----------------

  @spec start_link(keyword()) :: GenServer.on_start()
  # Called by :poolboy to instantiate the worker process.
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec run_protocol(pid(), module(), keyword()) :: {:ok, any()} | {:error, term()}
  def run_protocol(pid, protocol_mod, opts) do
    GenServer.call(pid, {:run_protocol, protocol_mod, opts})
  end

  # ----------- Callbacks ------------

  @impl GenServer
  def init(opts) do
    {:ok, start_session(opts)}
  end

  @impl GenServer
  def handle_call({:run_protocol, protocol_mod, params}, _from, state) do
    %{opts: opts, session_id: session_id} = state

    response =
      session_id
      |> protocol_mod.new(params)
      |> run_protocol_through_browser(opts)

    case increase_session_uses(state) do
      {:max_uses_reached, new_state} ->
        {:reply, response, new_state, {:continue, :restart_session}}

      {_, new_state} ->
        {:reply, response, new_state}
    end
  end

  @impl GenServer
  def handle_continue(:restart_session, state) do
    %{opts: opts, target_id: target_id} = state

    {:ok, true} =
      [targetId: target_id]
      |> CloseTarget.new()
      |> run_protocol_through_browser(opts)

    {:noreply, start_session(opts)}
  end

  defp start_session(opts) do
    {:ok, %{"targetId" => target_id, "sessionId" => session_id}} =
      opts
      |> Keyword.put_new(:offline, true)
      |> SpawnSession.new()
      |> run_protocol_through_browser(opts)

    %{
      opts: opts,
      target_id: target_id,
      session_id: session_id,
      session_uses: 0
    }
  end

  defp run_protocol_through_browser(protocol, opts) do
    Browser.run_protocol(Keyword.fetch!(opts, :chromic), protocol)
  end

  defp increase_session_uses(state) do
    %{opts: opts, session_uses: old_session_uses} = state

    session_uses = old_session_uses + 1
    max_session_uses = Keyword.get(opts, :max_session_uses, @default_max_session_uses)

    {
      session_uses >= max_session_uses && :max_uses_reached,
      %{state | session_uses: session_uses}
    }
  end
end
