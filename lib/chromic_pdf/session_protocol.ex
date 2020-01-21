defmodule ChromicPDF.SessionProtocol do
  @moduledoc false

  import ChromicPDF.JsonRPC
  alias ChromicPDF.JsonRPCState

  @type state :: pid()

  defdelegate start_link, to: JsonRPCState

  @spec start_navigation(state(), url :: binary()) :: :ok
  def start_navigation(state, url) do
    respond_with_chrome_msg(
      state,
      "Page.navigate",
      %{"url" => url}
    )
  end

  @spec start_printing(state(), opts :: map()) :: :ok
  def start_printing(state, opts) do
    respond_with_chrome_msg(
      state,
      "Page.printToPDF",
      opts
    )
  end

  @spec enable_page_notifications(state()) :: :ok
  def enable_page_notifications(state) do
    respond_with_chrome_msg(
      state,
      "Page.enable",
      %{}
    )
  end

  @spec handle_chrome_msg_in(state(), msg :: binary()) :: :ok
  def handle_chrome_msg_in(state, msg) do
    case decode_and_classify(state, msg) do
      {:response, "Page.navigate", %{"frameId" => frame_id}} ->
        respond({:navigation_started, frame_id})

      {:notification, "Page.frameStoppedLoading", %{"frameId" => frame_id}} ->
        respond({:navigation_finished, frame_id})

      {:response, "Page.printToPDF", %{"data" => data}} ->
        respond({:pdf_printed, data})

      _anything_else ->
        :ok
    end
  end

  defp respond_with_chrome_msg(state, method, params) do
    msg = encode(state, method, params)
    respond({:chrome_msg_out, msg})
  end

  defp respond(msg) do
    send(self(), msg)
    :ok
  end
end
