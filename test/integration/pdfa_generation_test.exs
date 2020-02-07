defmodule ChromicPDF.PDFAGenerationTest do
  use ExUnit.Case, async: false

  @test_html Path.expand("../fixtures/test.html", __ENV__.file)
  @output Path.expand("../test.pdf", __ENV__.file)

  setup do
    {:ok, _pid} = start_supervised(ChromicPDF)
    :ok
  end

  test "PDF/A-2b generation" do
    try do
      assert ChromicPDF.print_to_pdfa("file://#{@test_html}", %{}, @output) == :ok

      assert File.exists?(@output)

      {output, 0} = System.cmd("verapdf", ["-f", "2b", @output])
      assert String.contains?(output, ~S(validationReports compliant="1"))

    after
      File.rm_rf!(@output)
    end
  end
end
