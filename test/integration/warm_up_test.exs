# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.WarmUpTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO
  alias Mix.Tasks.ChromicPdf.WarmUp

  describe "ChromicPDF.warm_up/0" do
    test "fires a one-off chrome task to warm up Chrome's caches" do
      assert ChromicPDF.warm_up() == {:ok, ""}
    end

    test "returns stderr when given discard_stderr: false" do
      # Chrome crashes when given --dump-dom and more than one positional (non --) argument.
      {:ok, stderr} =
        ChromicPDF.warm_up(discard_stderr: false, chrome_args: "another_positional_arg")

      assert stderr =~ "Open multiple tabs is only supported when remote debugging is enabled" ||
               stderr =~ "Multiple targets are not supported"
    end
  end

  describe "chromic_pdf.warm_up mix task" do
    test "fires a one-off chrome task and prints a runtime measurement to console" do
      output = capture_io(fn -> WarmUp.run([]) end)
      assert output =~ "Chrome warm-up finished in"
    end
  end
end
