defmodule ChromicPDF.TemplateTest do
  use ExUnit.Case, async: false
  import ChromicPDF.Utils, only: [system_cmd!: 2]

  @output Path.expand("../test.pdf", __ENV__.file)

  defp print_to_pdf(source_and_opts, cb) do
    assert ChromicPDF.print_to_pdf(source_and_opts, output: @output) == :ok
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

    @tag :pdftotext
    test "`source_and_options/1` can be used as the source param for `print_to_pdf/2`" do
      ChromicPDF.Template.source_and_options(
        content: "<p>Hello</p>",
        header: "<p>header</p>",
        footer: "<p>footer</p>",
        header_height: "40mm",
        footer_height: "40mm"
      )
      |> print_to_pdf(fn text ->
        assert String.contains?(text, "Hello")
        assert String.contains?(text, "header")
        assert String.contains?(text, "footer")
      end)
    end
  end
end
