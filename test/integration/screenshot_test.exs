defmodule ChromicPDF.ScreenshotTest do
  use ExUnit.Case, async: false

  @test_html Path.expand("../fixtures/test.html", __ENV__.file)

  describe "Taking screenshots" do
    setup do
      start_supervised!(ChromicPDF)
      :ok
    end

    test "it can take a screenshot PDF from file:/// URLs" do
      assert {:ok, blob} = ChromicPDF.capture_screenshot({:url, "file://#{@test_html}"})
      assert blob =~ ~r<^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$>
    end

    test "it passes options to the captureScreenshot call" do
      assert {:ok, png} = ChromicPDF.capture_screenshot({:url, "file://#{@test_html}"})

      assert {:ok, jpeg} =
               ChromicPDF.capture_screenshot(
                 {:url, "file://#{@test_html}"},
                 capture_screenshot: %{format: "jpeg"}
               )

      refute png == jpeg
    end
  end
end
