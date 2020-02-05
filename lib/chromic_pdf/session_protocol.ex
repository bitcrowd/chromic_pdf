defmodule ChromicPDF.SessionProtocol do
  @moduledoc false

  @spec start_navigation(url :: binary()) :: :ok
  def start_navigation(url) do
    respond_with_chrome_msg("Page.navigate", %{"url" => url})
  end

  @spec start_printing(opts :: map()) :: :ok
  def start_printing(opts) do
    respond_with_chrome_msg("Page.printToPDF", opts)
  end

  @spec enable_page_notifications() :: :ok
  def enable_page_notifications do
    respond_with_chrome_msg("Page.enable", %{})
  end

  @spec handle_chrome_msg_in(msg :: ChromicPDF.JsonRPCChannel.decoded_message()) :: :ok
  def handle_chrome_msg_in(msg) do
    case msg do
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

  defp respond_with_chrome_msg(method, params) do
    respond({:chrome_msg_out, {:call, method, params}})
  end

  defp respond(msg) do
    send(self(), msg)
    :ok
  end
end
