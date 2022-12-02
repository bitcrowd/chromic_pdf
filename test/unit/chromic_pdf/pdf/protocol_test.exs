# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.ProtocolTest do
  use ExUnit.Case, async: true
  alias ChromicPDF.PrintToPDF

  describe "Inspect.ChromicPDF.Protocol" do
    test "looks reasonable and does not leak client data" do
      opts = [
        source_type: "html",
        source: "<html>...",
        output: "/some/path",
        capture_screenshot: %{
          "format" => "jpeg",
          "quality" => 100,
          "clip" => "some-viewport",
          "fromSurface" => true,
          "captureBeyondViewport" => true
        },
        print_to_pdf: %{
          "landscape" => true,
          "displayHeaderFooter" => true,
          "printBackground" => true,
          "scale" => 1,
          "paperWidth" => 1,
          "paperHeight" => 1,
          "marginTop" => 1,
          "marginBottom" => 1,
          "marginLeft" => 1,
          "marginRight" => 1,
          "pageRanges" => "1-2",
          "preferCSSPageSize" => true
        },
        wait_for: %{selector: "foo", attribute: "bar"},
        evaluate: "someFunction();",
        size: 1,
        init_timeout: 1,
        timeout: 1,
        offline: true,
        disable_scripts: true,
        max_session_uses: 1,
        session_pool: 1,
        no_sandbox: true,
        discard_stderr: true,
        chrome_args: "some-args",
        chrome_executable: "chromium",
        ignore_certificate_errors: true,
        ghostscript_pool: 1,
        on_demand: true
      ]

      inspected = inspect(PrintToPDF.new("12345", opts))

      assert inspected =~ ~s(:__protocol__ => ChromicPDF.PrintToPDF)
      assert inspected =~ ~s("captureBeyondViewport" => true)
      assert inspected =~ ~s("clip" => "some-viewport")
      assert inspected =~ ~s("format" => "jpeg")
      assert inspected =~ ~s("fromSurface" => true)
      assert inspected =~ ~s("quality" => 10)
      assert inspected =~ ~s(:chrome_args => "some-args")
      assert inspected =~ ~s(:chrome_executable => "chromium")
      assert inspected =~ ~s(:disable_scripts => true)
      assert inspected =~ ~s(:discard_stderr => true)
      assert inspected =~ ~s(:evaluate => "someFunction(\);")
      assert inspected =~ ~s(:ghostscript_pool => 1)
      assert inspected =~ ~s(:ignore_certificate_errors => true)
      assert inspected =~ ~s(:init_timeout => 1)
      assert inspected =~ ~s(:max_session_uses => 1)
      assert inspected =~ ~s(:no_sandbox => true)
      assert inspected =~ ~s(:offline => true)
      assert inspected =~ ~s(:on_demand => true)
      assert inspected =~ ~s(:output => "[FILTERED]")
      assert inspected =~ ~s("displayHeaderFooter" => true)
      assert inspected =~ ~s("landscape" => true)
      assert inspected =~ ~s("marginBottom" => 1)
      assert inspected =~ ~s("marginLeft" => 1)
      assert inspected =~ ~s("marginRight" => 1)
      assert inspected =~ ~s("marginTop" => 1)
      assert inspected =~ ~s("pageRanges" => "1-2")
      assert inspected =~ ~s("paperHeight" => 1)
      assert inspected =~ ~s("paperWidth" => 1)
      assert inspected =~ ~s("preferCSSPageSize" => true)
      assert inspected =~ ~s("printBackground" => true)
      assert inspected =~ ~s("scale" => )
      assert inspected =~ ~s(:session_pool => 1)
      assert inspected =~ ~s(:size => 1)
      assert inspected =~ ~s(:source => "[FILTERED]")
      assert inspected =~ ~s(:source_type => "html")
      assert inspected =~ ~s(:timeout => 1)
      assert inspected =~ ~s(:wait_for => %{attribute: "bar", selector: "foo"})
      assert inspected =~ ~s("sessionId" => "12345)
      assert inspected =~ "steps"
    end
  end
end
