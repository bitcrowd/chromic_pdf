defmodule ChromicPDF.CaptureScreenshot do
  @moduledoc false

  import ChromicPDF.ProtocolMacros

  steps do
    include_protocol(ChromicPDF.Navigate)

    call(:capture, "Page.captureScreenshot", &Map.get(&1, :capture_screenshot, %{}), %{})
    await_response(:captured, ["data"])

    include_protocol(ChromicPDF.ResetTarget)

    output("data")
  end
end
