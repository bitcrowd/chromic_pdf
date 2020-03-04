defmodule ChromicPDF.PrintToPDF do
  @moduledoc false

  import ChromicPDF.ProtocolMacros
  alias ChromicPDF.Protocol

  steps do
    if_option {:offline, true} do
      call(
        :offline_mode,
        "Network.emulateNetworkConditions",
        [],
        %{
          "offline" => true,
          "latency" => 0,
          "downloadThroughput" => 0,
          "uploadThroughput" => 0
        }
      )
    end

    if_option {:offline, false} do
      call(
        :online_mode,
        "Network.emulateNetworkConditions",
        [],
        %{
          "offline" => false,
          "latency" => 0,
          "downloadThroughput" => -1,
          "uploadThroughput" => -1
        }
      )
    end

    if_option {:source_type, :html} do
      call(:get_frame_tree, "Page.getFrameTree", [], %{})
      await_response(:frame_tree, [{["frameTree", "frame", "id"], "frameId"}])
      call(:set_content, "Page.setDocumentContent", [:html, "frameId"], %{})
      await_response(:content_set, [])
    end

    if_option {:source_type, :url} do
      call(:navigate, "Page.navigate", [:url], %{})
      await_response(:navigated, ["frameId"])
      await_notification(:frame_stopped_loading, "Page.frameStoppedLoading", ["frameId"], [])
    end

    call(:print_to_pdf, "Page.printToPDF", &Map.get(&1, :print_to_pdf, %{}), %{})
    await_response(:printed, ["data"])
    reply("data")

    call(:blank, "Page.navigate", [], %{"url" => "about:blank"})
    await_response(:blanked, ["frameId"])
  end
end
