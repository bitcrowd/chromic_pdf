# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.ScreenshotTest do
  use ChromicPDF.Case, async: false
  import ChromicPDF.TestAPI
  import ChromicPDF.Utils
  import ChromicPDF.ChromeRunner, only: [version: 0]

  @large_html Path.expand("../fixtures/large.html", __ENV__.file)

  describe "Taking screenshots" do
    setup do
      start_supervised!(ChromicPDF)
      :ok
    end

    test "capture_screenshot takes a screenshot and returns a Base64-encoded blob" do
      assert {:ok, blob} = capture_screenshot()
      assert blob =~ ~r<^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$>
    end

    @tag :identify
    test "custom options to the captureScreenshot call" do
      assert {"PNG", _, _} = capture_screenshot_and_identify(capture_screenshot: [format: "png"])

      assert {"JPEG", _, _} =
               capture_screenshot_and_identify(capture_screenshot: [format: "jpeg"])
    end

    @tag :identify
    test ":full_page resizes the the device dimensions to fit the content" do
      if semver_compare(version(), [91]) in [:eq, :gt] do
        {_, _, height} = capture_screenshot_and_identify(source: {:url, "file://#{@large_html}"})
        assert height < 4000

        {_, _, height} =
          capture_screenshot_and_identify(
            source: {:url, "file://#{@large_html}"},
            full_page: true
          )

        assert height >= 4000
      end
    end
  end
end
