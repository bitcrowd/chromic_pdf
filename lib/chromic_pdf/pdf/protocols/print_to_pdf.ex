defmodule ChromicPDF.PrintToPDF do
  @moduledoc false

  import ChromicPDF.ProtocolMacros
  alias ChromicPDF.Protocol

  steps do
    if_option :set_cookie do
      call(:set_cookie, "Network.setCookie", &Map.fetch!(&1, :set_cookie), %{})
      await_response(:cookie_set, [])
    end

    if_option {:source_type, :html} do
      call(:get_frame_tree, "Page.getFrameTree", [], %{})
      await_response(:frame_tree, [{["frameTree", "frame", "id"], "frameId"}])
      call(:set_content, "Page.setDocumentContent", [:html, "frameId"], %{})
      await_response(:content_set, [])
    end

    if_option {:source_type, :url} do
      call(:navigate, "Page.navigate", [:url], %{})

      await_response(:navigated, ["frameId"]) do
        case get_in(msg, ["result", "errorText"]) do
          nil ->
            :ok

          error ->
            {:error, error}
        end
      end

      await_notification(:frame_stopped_loading, "Page.frameStoppedLoading", ["frameId"], [])
    end

    call(:print_to_pdf, "Page.printToPDF", &Map.get(&1, :print_to_pdf, %{}), %{})
    await_response(:printed, ["data"])

    call(:blank, "Page.navigate", [], %{"url" => "about:blank"})
    await_response(:blanked, ["frameId"])

    call(:reset_history, "Page.resetNavigationHistory", [], %{})
    await_response(:history_reset, [])

    if_option :set_cookie do
      call(:clear_cookies, "Network.clearBrowserCookies", [], %{})
      await_response(:cleared, [])
    end

    reply("data")
  end
end
