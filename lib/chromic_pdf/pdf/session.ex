defmodule ChromicPDF.Session do
  @moduledoc false

  use GenServer
  alias ChromicPDF.{Browser, PrintToPDF, SpawnSession}

  # ------------- API ----------------

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  # Called by :poolboy to instantiate the worker process.
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @spec print_to_pdf(pid(), url :: binary(), params :: keyword(), output :: binary()) :: :ok
  # Prints a PDF by navigating the session target to a URL.
  def print_to_pdf(pid, url, params, output) do
    params = %{
      print_to_pdf_opts: Keyword.get(params, :print_to_pdf, %{}),
      url: url,
      output: output
    }

    GenServer.call(pid, {:print_to_pdf, params})
  end

  # ----------- Callbacks ------------

  @impl GenServer
  def init(args) do
    browser =
      args
      |> Keyword.fetch!(:chromic)
      |> Browser.server_name()

    protocol = SpawnSession.new(args)
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
