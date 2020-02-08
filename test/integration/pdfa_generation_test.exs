defmodule ChromicPDF.PDFAGenerationTest do
  use ExUnit.Case, async: false

  @test_html Path.expand("../fixtures/test.html", __ENV__.file)
  @output Path.expand("../test.pdf", __ENV__.file)

  setup do
    {:ok, _pid} = start_supervised(ChromicPDF)
    :ok
  end

  describe "PDF/A-2b conversion" do
    defp print_to_pdfa(pdfa_opts \\ [], cb) do
      assert ChromicPDF.print_to_pdfa("file://#{@test_html}", %{}, pdfa_opts, @output) == :ok
      assert File.exists?(@output)
      cb.(@output)
    after
      File.rm_rf!(@output)
    end

    test "it generates PDF files in compliance with the PDF/A-2b standard" do
      print_to_pdfa(fn file ->
        {output, 0} = System.cmd("verapdf", ["-f", "2b", file])
        assert String.contains?(output, ~S(validationReports compliant="1"))
      end)
    end

    @info_opts %{
      author: "TestAuthor",
      title: "TestTitle",
      subject: "TestSubject",
      keywords: "TestKeywords",
      creator: "TestCreator",
      creation_date: DateTime.from_unix!(1_000_000_000),
      mod_date: DateTime.from_unix!(2_000_000_000)
    }

    test "it stores given Info metadata in the generated PDF file" do
      print_to_pdfa([info: @info_opts], fn file ->
        {output, 0} = System.cmd("pdfinfo", [file])

        assert String.contains?(output, "Author:         TestAuthor")
        assert String.contains?(output, "Title:          TestTitle")
        assert String.contains?(output, "Subject:        TestSubject")
        assert String.contains?(output, "Keywords:       TestKeywords")
        assert String.contains?(output, "Creator:        TestCreator")
        assert String.contains?(output, "CreationDate:   Sun Sep  9 01:46:40 2001")
        assert String.contains?(output, "ModDate:        Wed May 18 03:33:20 2033")
      end)
    end
  end
end
