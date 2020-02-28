defmodule ChromicPDF.Session do
  @moduledoc false

  use GenServer
  alias ChromicPDF.{Browser, CaptureScreenshot, PrintToPDF, SpawnSession}

  # ------------- API ----------------

  @spec start_link(keyword()) :: GenServer.on_start()
  # Called by :poolboy to instantiate the worker process.
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec print_to_pdf(pid(), tuple(), keyword()) :: binary()
  # Prints a PDF by navigating the session target to a URL.
  def print_to_pdf(pid, input, opts) do
    navigate_and_export(pid, PrintToPDF, input, opts)
  end

  @spec capture_screenshot(pid(), tuple(), keyword()) :: binary()
  # Captures a screenshot by navigating the session target to a URL.
  def capture_screenshot(pid, input, opts) do
    navigate_and_export(pid, CaptureScreenshot, input, opts)
  end

  @spec navigate_and_export(pid(), module(), {atom(), binary()}, keyword()) :: binary()
  defp navigate_and_export(pid, protocol, {source_type, source}, opts) do
    opts =
      Keyword.merge(
        [
          {:source_type, source_type},
          {source_type, source}
        ],
        opts
      )

    GenServer.call(pid, {:run_protocol, protocol, opts})
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
  def handle_call({:run_protocol, protocol, params}, _from, state) do
    %{browser: browser, session_id: session_id} = state

    protocol = protocol.new(session_id, params)
    response = Browser.run(browser, protocol)

    {:reply, response, state}
  end
end
