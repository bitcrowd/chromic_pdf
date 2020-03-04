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
      assert ChromicPDF.print_to_pdf(input, Keyword.put(pdf_params, :output, @output)) == :ok
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

    # credo:disable-for-next-line Credo.Check.Design.TagFIXME
    # FIXME: currently out-of-order
    #
    # Plan is to do this with
    #  https://chromedevtools.github.io/devtools-protocol/tot/Page#method-setDocumentContent
    @tag :pdftotext
    test "it prints PDF from HTML content" do
      print_to_pdf({:html, File.read!(@test_html)}, fn text ->
        assert String.contains?(text, "Hello ChromicPDF!")
      end)
    end

    # credo:disable-for-next-line Credo.Check.Design.TagFIXME
    # FIXME: Broken in recent Chrome
    #
    # This test case is currently broken on my machine, presumably due to a change in Chrome.
    # Previously we received a `frameStoppedLoading` event regardless of whether the page could be
    # loaded or not. Since this event isn't received anymore, this call instead aborts from a
    # timed out `GenServer.call/2` call. Fix could be proper error handling in the protocols. The
    # response to `Page.navigate` contains an error message:
    #
    #     %{
    #       "result" => %{
    #         "errorText" => "net::ERR_INTERNET_DISCONNECTED"
    #       }
    #     }
    @tag :skip
    @tag :pdftotext
    test "it does not print PDF from https:// URLs by default" do
      print_to_pdf({:url, "https://example.net"}, fn text ->
        assert String.trim(text) == ""
      end)
    end

    @tag :pdftotext
    test "it prints PDF from https:// URLs when given the offline: false parameter" do
      print_to_pdf({:url, "https://example.net"}, [offline: false], fn text ->
        assert String.contains?(text, "Example Domain")
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

    test "it can return the Base64 encoded PDF" do
      assert {:ok, blob} = ChromicPDF.print_to_pdf({:url, "file://#{@test_html}"})
      assert blob =~ ~r<^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$>
    end

    test "it can yield a temporary file to a callback" do
      ChromicPDF.print_to_pdf({:url, "file://#{@test_html}"},
        output: fn path ->
          assert File.exists?(path)
          send(self(), path)
        end
      )

      receive do
        path -> refute File.exists?(path)
      end
    end
  end
end
