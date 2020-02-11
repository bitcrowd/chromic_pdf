defmodule ChromicPDF.PDFGenerationTest do
  use ExUnit.Case, async: false
  import ChromicPDF.Utils, only: [system_cmd!: 2]

  @test_html Path.expand("../fixtures/test.html", __ENV__.file)
  @output Path.expand("../test.pdf", __ENV__.file)

  describe "PDF printing" do
    setup do
      start_supervised!(ChromicPDF)
      :ok
    end

    defp print_to_pdf(cb) do
      print_to_pdf({:url, "file://#{@test_html}"}, [], cb)
    end

    defp print_to_pdf(params, cb) when is_list(params) do
      print_to_pdf({:url, "file://#{@test_html}"}, params, cb)
    end

    defp print_to_pdf(input, cb) do
      print_to_pdf(input, [], cb)
    end

    defp print_to_pdf(input, pdf_params, cb) do
      assert ChromicPDF.print_to_pdf(input, pdf_params, @output) == :ok
      assert File.exists?(@output)

      text = system_cmd!("pdftotext", [@output, "-"])
      cb.(text)
    after
      File.rm_rf!(@output)
    end

    @tag :pdftotext
    test "it prints PDF from file:/// URLs" do
      print_to_pdf(fn text ->
        assert String.contains?(text, "Hello ChromicPDF!")
      end)
    end

    @tag :pdftotext
    test "it prints PDF from HTML content" do
      print_to_pdf({:html, File.read!(@test_html)}, fn text ->
        assert String.contains?(text, "Hello ChromicPDF!")
      end)
    end

    @tag :pdftotext
    test "it does not print PDF from https:// URLs by default" do
      print_to_pdf({:url, "https://example.net"}, fn text ->
        assert String.trim(text) == ""
      end)
    end

    @tag :pdftotext
    test "it allows to pass thru options to printToPDF" do
      pdf_params = %{
        displayHeaderFooter: true,
        marginTop: 3,
        marginBottom: 3,
        headerTemplate: ~S(<span style="font-size: 40px">Header</span>),
        footerTemplate: ~S(<span style="font-size: 40px">Footer</span>)
      }

      print_to_pdf([print_to_pdf: pdf_params], fn text ->
        assert String.contains?(text, "Header")
        assert String.contains?(text, "Footer")
      end)
    end
  end

  describe "online mode" do
    setup do
      start_supervised!({ChromicPDF, offline: false})
      :ok
    end

    @tag :pdftotext
    test "it prints PDF from https:// URLs" do
      print_to_pdf({:url, "https://example.net"}, fn text ->
        assert String.contains?(text, "Example Domain")
      end)
    end
  end
end
