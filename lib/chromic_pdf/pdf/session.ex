defmodule ChromicPDF.Session do
  @moduledoc false

  use ChromicPDF.Channel
  alias ChromicPDF.{Browser, EnablePage, PrintToPDF}

  # ------------- API ----------------

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  # Called by :poolboy to instantiate the worker process.
  def start_link(args) do
    {:ok, pid} = GenServer.start_link(__MODULE__, args)
    Channel.start_protocol(pid, EnablePage)
    {:ok, pid}
  end

  @spec print_to_pdf(pid(), url :: binary(), params :: map(), output :: binary()) :: :ok
  # Prints a PDF by navigating the session target to a URL.
  def print_to_pdf(pid, url, params, output) do
    Channel.start_protocol(pid, PrintToPDF, {url, params, output})
  end

  # ----------- Callbacks ------------

  @impl ChromicPDF.Channel
  def init_upstream(args) do
    browser =
      args
      |> Keyword.fetch!(:chromic)
      |> Browser.server_name()

    {:ok, session_id} = Browser.spawn_session(browser)

    fn msg ->
      Browser.send_session_msg(browser, session_id, msg)
    end
  end
end
