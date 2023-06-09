# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.CaptureScreenshot do
  @moduledoc false

  import ChromicPDF.ProtocolMacros

  steps do
    include_protocol(ChromicPDF.Navigate)

    if_option :full_page do
      call(:get_layout_metrics, "Page.getLayoutMetrics", [], %{})
      await_response(:layout_metrics_got, ["cssContentSize"])

      call(
        :set_device_metrics_override,
        "Emulation.setDeviceMetricsOverride",
        [
          {"width", ["cssContentSize", "width"]},
          {"height", ["cssContentSize", "height"]}
        ],
        %{"mobile" => false, "deviceScaleFactor" => 1}
      )

      await_response(:device_metrics_override_set, [])
    end

    call(:capture, "Page.captureScreenshot", &Map.get(&1, :capture_screenshot, %{}), %{})
    await_response(:captured, ["data"])

    include_protocol(ChromicPDF.ResetTarget)

    output("data")
  end
end
