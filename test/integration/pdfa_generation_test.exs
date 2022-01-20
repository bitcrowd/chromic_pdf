defmodule ChromicPDF.PDFAGenerationTest do
  use ExUnit.Case, async: false
  import ChromicPDF.Utils, only: [system_cmd!: 2]

  @test_html Path.expand("../fixtures/test.html", __ENV__.file)

  setup do
    {:ok, _pid} = start_supervised(ChromicPDF)
    :ok
  end

  describe "PDF/A conversion" do
    defp print_to_pdfa(opts \\ [], cb) do
      opts = Keyword.put(opts, :output, cb)
      assert {:ok, _} = ChromicPDF.print_to_pdfa({:url, "file://#{@test_html}"}, opts)
    end

    @tag :verapdf
    test "it generates PDF files in compliance with the PDF/A-2b standard" do
      print_to_pdfa([pdfa_version: "2"], fn file ->
        output = system_cmd!("verapdf", ["-f", "2b", file])
        assert String.contains?(output, ~S(validationReports compliant="1"))
      end)
    end

    @tag :verapdf
    test "it generates PDF files in compliance with the PDF/A-3b standard (by default)" do
      print_to_pdfa(fn file ->
        output = system_cmd!("verapdf", ["-f", "3b", file])
        assert String.contains?(output, ~S(validationReports compliant="1"))
      end)
    end

    test "it can yield a temporary file to a callback" do
      result =
        ChromicPDF.print_to_pdfa({:url, "file://#{@test_html}"},
          output: fn path ->
            assert File.exists?(path)
            send(self(), path)
            :some_result
          end
        )

      assert result == {:ok, :some_result}

      receive do
        path -> refute File.exists?(path)
      end
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

    @tag :pdfinfo
    test "it stores given Info metadata in the generated PDF file" do
      print_to_pdfa([info: @info_opts], fn file ->
        output = system_cmd!("pdfinfo", [file])

        assert output =~ ~r/Author:\s+TestAuthor/
        assert output =~ ~r/Title:\s+TestTitle/
        assert output =~ ~r/Subject:\s+TestSubject/
        assert output =~ ~r/Keywords:\s+TestKeywords/
        assert output =~ ~r/Creator:\s+TestCreator/
        assert output =~ ~r/CreationDate:\s+Sun Sep  9/
        assert output =~ ~r/ModDate:\s+Wed May 18/
      end)
    end

    @tag :pdfinfo
    test "it allows to pass additional PostScript code to the converter" do
      pdfa_opts = [
        pdfa_def_ext: "[/Title (OverriddenTitle) /DOCINFO pdfmark"
      ]

      print_to_pdfa(pdfa_opts, fn file ->
        output = system_cmd!("pdfinfo", [file])
        assert output =~ ~r/Title:\s+OverriddenTitle/
      end)
    end
  end
end
