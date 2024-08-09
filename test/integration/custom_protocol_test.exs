# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.CustomProtocolTest do
  use ChromicPDF.Case, async: false
  import ChromicPDF.TestAPI

  defmodule BypassCSP do
    import ChromicPDF.ProtocolMacros

    steps do
      call(:set_bypass_csp, "Page.setBypassCSP", [], %{"enabled" => true})
      await_response(:bypass_csp_set, [])

      include_protocol(ChromicPDF.PrintToPDF)
    end
  end

  defmodule FixedScreenMetrics do
    import ChromicPDF.ProtocolMacros

    steps do
      call(
        :device_metrics,
        "Emulation.setDeviceMetricsOverride",
        [],
        %{"width" => 200, "height" => 200, "mobile" => false, "deviceScaleFactor" => 1}
      )

      await_response(:device_metrics_response, [])

      include_protocol(ChromicPDF.CaptureScreenshot)
    end
  end

  defmodule GetUserAgent do
    import ChromicPDF.ProtocolMacros

    steps do
      call(:get_version, "Browser.getVersion", [], %{})
      await_response(:version, ["userAgent"])

      output("userAgent")
    end
  end

  setup do
    start_supervised!(ChromicPDF)
    :ok
  end

  describe ":protocol option to print_to_pdf/2" do
    @html_with_csp """
    <html>
      <head>
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'">
      </head>
      <body>
        <iframe src="data:text/html;charset=utf-8,%3Chtml%3E%3Cbody%3Efrom iframe%3C/body%3E%3C/html%3E">
      </body>
    </html>
    """

    @tag :pdftotext
    test "allows to override the default protocol" do
      print_to_pdf({:html, @html_with_csp}, fn text ->
        refute String.contains?(text, "from iframe")
      end)

      print_to_pdf({:html, @html_with_csp}, [protocol: BypassCSP], fn text ->
        assert String.contains?(text, "from iframe")
      end)
    end
  end

  describe ":protocol option to capture_screenshot/2" do
    test "allows to set a custom protocol for capture_screenshot/2" do
      assert {_, 200, 200} = capture_screenshot_and_identify(protocol: FixedScreenMetrics)
    end
  end

  describe "run_protocol/2" do
    test "allows to run custom protocols and get their output" do
      assert {:ok, user_agent} = ChromicPDF.run_protocol(GetUserAgent)
      assert user_agent =~ ~r/chrom/i
    end
  end
end
