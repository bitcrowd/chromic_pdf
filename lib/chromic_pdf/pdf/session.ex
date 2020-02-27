defmodule ChromicPDF.Session do
  @moduledoc false

  use GenServer
  alias ChromicPDF.{Browser, PrintToPDF, SpawnSession}

  # ------------- API ----------------

  @spec start_link(keyword()) :: GenServer.on_start()
  # Called by :poolboy to instantiate the worker process.
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec print_to_pdf(pid(), {atom(), binary()}, keyword()) :: :ok
  # Prints a PDF by navigating the session target to a URL.
  def print_to_pdf(pid, {source_type, source}, opts) do
    opts =
      Keyword.merge(
        [
          {:source_type, source_type},
          {source_type, source}
        ],
        opts
      )

    GenServer.call(pid, {:print_to_pdf, opts})
  end

  # ----------- Callbacks ------------

  @impl GenServer
  def init(opts) do
    opts = Keyword.put_new(opts, :offline, true)

    browser =
      opts
      |> Keyword.fetch!(:chromic)
      |> Browser.server_name()

    protocol = SpawnSession.new(opts)
    session_id = Browser.run(browser, protocol)

    {:ok, %{session_id: session_id, browser: browser}}
  end

  @impl GenServer
  def handle_call({:print_to_pdf, params}, _from, state) do
    %{browser: browser, session_id: session_id} = state

    protocol = PrintToPDF.new(session_id, params)
    response = Browser.run(browser, protocol)

    {:reply, response, state}
  end
end
