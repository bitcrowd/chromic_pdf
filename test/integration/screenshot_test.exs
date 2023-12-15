# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.ScreenshotTest do
  use ChromicPDF.Case, async: false
  import ChromicPDF.Utils
  import ChromicPDF.ChromeRunner, only: [version: 0]

  @test_html Path.expand("../fixtures/test.html", __ENV__.file)
  @large_html Path.expand("../fixtures/large.html", __ENV__.file)

  defp capture_screenshot(opts \\ []) do
    {source, opts} = Keyword.pop(opts, :source)

    ChromicPDF.capture_screenshot(source || {:url, "file://#{@test_html}"}, opts)
  end

  defp capture_screenshot_and_identify(opts) do
    with_tmp_dir(fn tmp_dir ->
      img = "#{tmp_dir}/test"
      :ok = capture_screenshot([{:output, img} | opts])

      {stdout, 0} = System.cmd("identify", [img])

      [_, format, dimensions | _] = String.split(stdout, " ")

      %{"width" => width, "height" => height} =
        Regex.named_captures(~r/^(?<width>\d+)x(?<height>\d+)$/, dimensions)

      {format, String.to_integer(width), String.to_integer(height)}
    end)
  end

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
