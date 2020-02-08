defmodule ChromicPDF.PDFGenerationTest do
  use ExUnit.Case, async: false

  @test_html Path.expand("../fixtures/test.html", __ENV__.file)
  @output Path.expand("../test.pdf", __ENV__.file)

  setup do
    {:ok, _pid} = start_supervised(ChromicPDF)
    :ok
  end

  describe "PDF printing" do
    defp print_to_pdf(cb) do
      print_to_pdf("file://#{@test_html}", %{}, cb)
    end

    defp print_to_pdf(url, cb) when is_binary(url) do
      print_to_pdf(url, %{}, cb)
    end

    defp print_to_pdf(params, cb) when is_map(params) do
      print_to_pdf("file://#{@test_html}", params, cb)
    end

    defp print_to_pdf(url, pdf_params, cb) do
      assert ChromicPDF.print_to_pdf({:url, url}, pdf_params, @output) == :ok
      assert File.exists?(@output)

      {text, 0} = System.cmd("pdftotext", [@output, "-"])
      cb.(text)
    after
      File.rm_rf!(@output)
    end

    test "prints PDF from file:/// URLs" do
      print_to_pdf(fn text ->
        assert String.contains?(text, "Hello ChromicPDF!")
      end)
    end

    test "prints PDF from https:// URLs" do
      print_to_pdf("https://example.net", fn text ->
        assert String.contains?(text, "Example Domain")
      end)
    end

    test "allows to pass thru options to printToPDF" do
      pdf_params = %{
        displayHeaderFooter: true,
        marginTop: 3,
        marginBottom: 3,
        headerTemplate: ~S(<span style="font-size: 40px">Header</span>),
        footerTemplate: ~S(<span style="font-size: 40px">Footer</span>)
      }

      print_to_pdf(pdf_params, fn text ->
        assert String.contains?(text, "Header")
        assert String.contains?(text, "Footer")
      end)
    end
  end
end
