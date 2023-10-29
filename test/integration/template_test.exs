# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.TemplateTest do
  use ChromicPDF.Case, async: false
  import ChromicPDF.TestAPI
  import ChromicPDF.Template

  describe "using Template helpers" do
    setup do
      start_supervised!(ChromicPDF)
      :ok
    end

    @header_and_style_opts [
      header: "<p>header</p>",
      footer: "<p>footer</p>",
      header_height: "40mm",
      footer_height: "40mm"
    ]

    @content_and_header_and_style_opts [{:content, "<p>Hello</p>"} | @header_and_style_opts]

    @tag :pdftotext
    test "`source_and_options/1` can be used as the source param for `print_to_pdf/2`" do
      @content_and_header_and_style_opts
      |> source_and_options()
      |> print_to_pdf(fn text ->
        assert String.contains?(text, "Hello")
        assert String.contains?(text, "header")
        assert String.contains?(text, "footer")
      end)
    end

    test "`source_and_options/1` can be used as the source param for `capture_screenshot/2`" do
      assert {:ok, _} =
               @content_and_header_and_style_opts
               |> source_and_options()
               |> ChromicPDF.capture_screenshot()
    end

    @tag :pdftotext
    test "`source_and_options/1` can be used as the source param for `print_to_pdfa/2`" do
      assert {:ok, _} =
               @content_and_header_and_style_opts
               |> source_and_options()
               |> ChromicPDF.print_to_pdfa()
    end

    @tag :pdftotext
    test "`options/1` can be used as the opts param for `print_to_pdf/2`" do
      opts = options(@header_and_style_opts)

      print_to_pdf({:html, "<p>Hello</p>"}, opts, fn text ->
        assert String.contains?(text, "Hello")
        assert String.contains?(text, "header")
        assert String.contains?(text, "footer")
      end)
    end

    test "`options/1` can be used as the opts param for `capture_screenshot/2`" do
      opts = options(@header_and_style_opts)
      assert {:ok, _} = ChromicPDF.capture_screenshot({:html, "<p>Hello</p>"}, opts)
    end

    test "`options/1` can be used as the opts param for `print_to_pdfa/2`" do
      opts = options(@header_and_style_opts)
      assert {:ok, _} = ChromicPDF.print_to_pdfa({:html, "<p>Hello</p>"}, opts)
    end

    @tag :pdfinfo
    test "it keeps the page size when landscape param is false" do
      @content_and_header_and_style_opts
      |> Keyword.merge(size: :a4, landscape: false)
      |> source_and_options()
      |> print_to_pdf(fn _text, info ->
        # Older Chrome/Skia versions calculated slightly lower pts from the 8.3 inch width.
        # Older versions were not detected as A4 by pdfinfo.
        assert info =~ ~r/Page size:\s+(597\.12|598\.08) x 841\.92 pts( \(A4\))?/
      end)
    end

    @tag :pdfinfo
    test "it inverts the page size when landscape param is true" do
      @content_and_header_and_style_opts
      |> Keyword.merge(size: :a4, landscape: true)
      |> source_and_options()
      |> print_to_pdf(fn _text, info ->
        assert info =~ ~r/Page size:\s+841\.92 x (597\.12|598\.08) pts/
      end)
    end
  end
end
