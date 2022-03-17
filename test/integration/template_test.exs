defmodule ChromicPDF.TemplateTest do
  use ExUnit.Case, async: false
  import ChromicPDF.Utils, only: [system_cmd!: 2]

  @output Path.expand("../test.pdf", __ENV__.file)

  defp print_to_pdf(opts, cb) do
    ChromicPDF.Template.source_and_options(opts)
    |> print_to_pdf(&ChromicPDF.print_to_pdf/2, cb)
  end

  defp print_to_pdf(source_and_opts, print_fun, cb) do
    assert print_fun.(source_and_opts, output: @output) == :ok
    assert File.exists?(@output)

    text = system_cmd!("pdftotext", [@output, "-"])
    cb.(text)
  after
    File.rm_rf!(@output)
  end

  describe "using Template helpers" do
    setup do
      start_supervised!(ChromicPDF)
      :ok
    end

    def assert_print_fun_accepts_source_and_options(print_fun) do
      ChromicPDF.Template.source_and_options(
        content: "<p>Hello</p>",
        header: "<p>header</p>",
        footer: "<p>footer</p>",
        header_height: "40mm",
        footer_height: "40mm"
      )
      |> print_to_pdf(print_fun, fn text ->
        assert String.contains?(text, "Hello")
        assert String.contains?(text, "header")
        assert String.contains?(text, "footer")
      end)
    end

    @tag :pdftotext
    test "`source_and_options/1` can be used as the source param for `print_to_pdf/2`" do
      assert_print_fun_accepts_source_and_options(&ChromicPDF.print_to_pdf/2)
    end

    @tag :pdftotext
    test "`source_and_options/1` can be used as the source param for `print_to_pdfa/2`" do
      assert_print_fun_accepts_source_and_options(&ChromicPDF.print_to_pdfa/2)
    end

    @tag :pdfinfo
    test "it keeps the page size when landscape param is false" do
      pdf_params = [
        content: "<p>Hello</p>",
        size: :a4,
        landscape: false
      ]

      print_to_pdf(pdf_params, fn _text ->
        output = system_cmd!("pdfinfo", [@output])

        assert output =~ ~r/Page size:\s+597.12 x 841.92 pts/
      end)
    end

    @tag :pdfinfo
    test "it inverts the page size when landscape param is true" do
      pdf_params = [
        content: "<p>Hello</p>",
        size: :a4,
        landscape: true
      ]

      print_to_pdf(pdf_params, fn _text ->
        output = system_cmd!("pdfinfo", [@output])

        assert output =~ ~r/Page size:\s+841.92 x 597.12 pts/
      end)
    end
  end
end
