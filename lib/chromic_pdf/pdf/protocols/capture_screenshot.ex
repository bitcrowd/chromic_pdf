defmodule ChromicPDF.CaptureScreenshot do
  @moduledoc false

  import ChromicPDF.ProtocolMacros

  steps do
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

    call(:capture, "Page.captureScreenshot", &Map.get(&1, :capture_screenshot, %{}), %{})
    await_response(:captured, ["data"])

    output("data")
  end
end
