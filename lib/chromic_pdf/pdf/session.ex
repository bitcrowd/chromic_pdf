defmodule ChromicPDF.Session do
  @moduledoc false

  use GenServer
  alias ChromicPDF.{Browser, SpawnSession}

  # ------------- API ----------------

  @spec start_link(keyword()) :: GenServer.on_start()
  # Called by :poolboy to instantiate the worker process.
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec run_protocol(pid(), module(), keyword()) :: any()
  def run_protocol(pid, protocol_mod, opts) do
    GenServer.call(pid, {:run_protocol, protocol_mod, opts})
  end

  # ----------- Callbacks ------------

  @impl GenServer
  def init(opts) do
    browser =
      opts
      |> Keyword.fetch!(:chromic)
      |> Browser.server_name()

    session_id = Browser.run_protocol(browser, SpawnSession, opts)

    {:ok, %{session_id: session_id, browser: browser}}
  end

  @impl GenServer
  def handle_call({:run_protocol, protocol_mod, params}, _from, state) do
    %{browser: browser, session_id: session_id} = state

    protocol = protocol_mod.new(session_id, params)
    response = Browser.run_protocol(browser, protocol)

    {:reply, response, state}
  end
end
