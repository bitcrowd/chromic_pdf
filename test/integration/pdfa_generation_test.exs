defmodule ChromicPDF.PDFAGenerationTest do
  use ExUnit.Case, async: false
  import ChromicPDF.Utils, only: [system_cmd!: 2]
  require EEx

  @test_html Path.expand("../fixtures/test.html", __ENV__.file)
  @output Path.expand("../test.pdf", __ENV__.file)

  setup do
    {:ok, _pid} = start_supervised(ChromicPDF)
    :ok
  end

  describe "PDF/A conversion" do
    defp print_to_pdfa(pdfa_opts \\ [], cb) do
      assert ChromicPDF.print_to_pdfa({:url, "file://#{@test_html}"}, %{}, pdfa_opts, @output) ==
               :ok

      assert File.exists?(@output)
      cb.(@output)
    after
      File.rm_rf!(@output)
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

        assert String.contains?(output, "Author:         TestAuthor")
        assert String.contains?(output, "Title:          TestTitle")
        assert String.contains?(output, "Subject:        TestSubject")
        assert String.contains?(output, "Keywords:       TestKeywords")
        assert String.contains?(output, "Creator:        TestCreator")
        assert String.contains?(output, "CreationDate:   Sun Sep  9 01:46:40 2001")
        assert String.contains?(output, "ModDate:        Wed May 18 03:33:20 2033")
      end)
    end

    @tag :pdfinfo
    test "it allows to pass additional PostScript code to the converter" do
      pdfa_opts = [
        pdfa_def_ext: "[/Title (OverriddenTitle) /DOCINFO pdfmark"
      ]

      print_to_pdfa(pdfa_opts, fn file ->
        output = system_cmd!("pdfinfo", [file])
        assert String.contains?(output, "Title:          OverriddenTitle")
      end)
    end

    @zugferd_invoice_xml Path.expand("../fixtures/zugferd-invoice.xml", __ENV__.file)
    @embed_xml_ps_eex Path.expand("../fixtures/embed_xml.ps.eex", __ENV__.file)

    @external_resource @embed_xml_ps_eex

    EEx.function_from_file(:defp, :render_embed_xml_ps, @embed_xml_ps_eex, [:assigns])

    @tag :zuv
    test "it can generate ZUGFeRD-compliant invoices" do
      embed_xml_ps =
        render_embed_xml_ps(
          zugferd_xml: @zugferd_invoice_xml,
          zugferd_xml_file_date: ChromicPDF.Utils.to_postscript_date(DateTime.utc_now())
        )

      pdfa_opts = [
        pdfa_def_ext: embed_xml_ps
      ]

      print_to_pdfa(pdfa_opts, fn file ->
        output =
          system_cmd!(
            "java",
            ["-jar", System.fetch_env!("ZUV_JAR"), "--action", "validate", "-f", file]
          )

        assert String.contains?(output, ~S(validationReports compliant="1"))
      end)
    end
  end
end
