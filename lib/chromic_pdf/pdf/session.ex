defmodule ChromicPDF.Session do
  @moduledoc false

  use ChromicPDF.Channel
  alias ChromicPDF.{Browser, PrintToPDF}

  # ------------- API ----------------

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  # Called by :poolboy to instantiate the worker process.
  def start_link(args) do
    {:ok, pid} = GenServer.start_link(__MODULE__, args)

    {:ok, pid}
  end

  @spec print_to_pdf(pid(), url :: binary(), params :: keyword(), output :: binary()) :: :ok
  # Prints a PDF by navigating the session target to a URL.
  def print_to_pdf(pid, url, params, output) do
    print_to_pdf_opts = Keyword.get(params, :print_to_pdf, %{})
    Channel.start_protocol(pid, PrintToPDF, {url, print_to_pdf_opts, output})
  end

  # ----------- Callbacks ------------

  @impl ChromicPDF.Channel
  def init_upstream(args) do
    browser =
      args
      |> Keyword.fetch!(:chromic)
      |> Browser.server_name()

    {:ok, session_id} = Browser.spawn_session(browser)
    init_session(args)

    fn msg ->
      Browser.send_session_msg(browser, session_id, msg)
    end
  end

  defp init_session(args) do
    if Keyword.get(args, :offline, true) do
      Channel.send_call(
        self(),
        {"Network.emulateNetworkConditions",
         %{
           offline: true,
           latency: 0,
           downloadThroughput: 0,
           uploadThroughput: 0
         }}
      )
    end

    Channel.send_call(self(), {"Page.enable", %{}})
  end
end
