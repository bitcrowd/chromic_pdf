defmodule ChromicPDF.PDFGenerationTest do
  use ExUnit.Case, async: false
  import ChromicPDF.Utils, only: [system_cmd!: 2]

  @test_html Path.expand("../fixtures/test.html", __ENV__.file)
  @test_dynamic_html Path.expand("../fixtures/test_dynamic.html", __ENV__.file)
  @test_dynamic_latin1_html Path.expand("../fixtures/test_dynamic-latin1.html", __ENV__.file)
  @test_dynamic_pre_existing_html Path.expand(
                                    "../fixtures/test_dynamic_pre-existing.html",
                                    __ENV__.file
                                  )
  @test_image Path.expand("../fixtures/image_with_text.svg", __ENV__.file)

  @output Path.expand("../test.pdf", __ENV__.file)
  @test_server_port Application.compile_env!(:chromic_pdf, :test_server_port)

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

  describe "PDF printing" do
    setup do
      start_supervised!(ChromicPDF)
      :ok
    end

    @tag :pdftotext
    test "it prints PDF from file:// URLs" do
      print_to_pdf(fn text ->
        assert String.contains?(text, "Hello ChromicPDF!")
      end)
    end

    @tag :pdftotext
    test "it prints PDF from files (expanding to file://) URLs" do
      print_to_pdf({:url, @test_html}, fn text ->
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
    test "it waits for external resources when printing HTML content" do
      html = ~s(<img src="file://#{@test_image}" />)

      print_to_pdf({:html, html}, fn text ->
        assert String.contains?(text, "some text from an external svg")
      end)
    end

    test "it prints PDFs from https:// URLs by default" do
      print_to_pdf({:url, "https://example.net"}, fn text ->
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

    @tag :pdftotext
    test "it can deal with {:safe, iolist()} tuples" do
      print_to_pdf({:html, {:safe, [File.read!(@test_html)]}}, fn text ->
        assert String.contains?(text, "Hello ChromicPDF!")
      end)
    end

    @tag :pdftotext
    test "it accepts iolists in source and header/footer options" do
      pdf_params = %{
        displayHeaderFooter: true,
        marginTop: 3,
        marginBottom: 3,
        headerTemplate: [~S(<span style="font-size: 40px">), ["Header", "</span>"]]
      }

      print_to_pdf({:html, ["foo", ["bar"]]}, [print_to_pdf: pdf_params], fn text ->
        assert String.contains?(text, "Header")
        assert String.contains?(text, "foobar")
      end)
    end

    test "it can return the Base64 encoded PDF" do
      assert {:ok, blob} = ChromicPDF.print_to_pdf({:url, "file://#{@test_html}"})
      assert blob =~ ~r<^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$>
    end

    test "it can yield a temporary file to a callback" do
      result =
        ChromicPDF.print_to_pdf({:url, "file://#{@test_html}"},
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

    # The wait_for tests intentionally use umlauts in selectors and attributes.
    @tag :pdftotext
    test "it waits until defined selectors have given attribute when printing from `:url`" do
      params = [
        wait_for: %{selector: "#print-readyö", attribute: "ready-to-printö"}
      ]

      print_to_pdf({:url, "file://#{@test_dynamic_html}"}, params, fn text ->
        assert String.contains?(text, "Dynamic content from Javascript")
      end)
    end

    @tag :pdftotext
    test "it waits until defined selectors have given attribute when printing from `:url` with ISO-8859 (latin1) encoding" do
      params = [
        wait_for: %{selector: "#print-readyö", attribute: "ready-to-printö"}
      ]

      print_to_pdf({:url, "file://#{@test_dynamic_latin1_html}"}, params, fn text ->
        assert String.contains?(text, "Dynamic content from Javascript")
      end)
    end

    @tag :pdftotext
    test "it waits until defined selectors have given attribute when printing from `:html`" do
      params = [
        wait_for: %{selector: "#print-readyö", attribute: "ready-to-printö"}
      ]

      print_to_pdf({:html, File.read!(@test_dynamic_html)}, params, fn text ->
        assert String.contains?(text, "Dynamic content from Javascript")
      end)
    end

    test "it raises RuntimeError if defined selector already has the given attribute" do
      params = [
        wait_for: %{selector: "#print-readyö", attribute: "ready-to-printö"}
      ]

      assert_raise(
        RuntimeError,
        fn ->
          ChromicPDF.print_to_pdf({:url, "file://#{@test_dynamic_pre_existing_html}"}, params)
        end
      )
    end
  end

  describe "offline mode" do
    setup do
      start_supervised!({ChromicPDF, offline: true})
      :ok
    end

    @tag :pdftotext
    test "it does not print PDFs from https:// URLs when given the offline: true parameter" do
      assert_raise RuntimeError, ~r/net::ERR_INTERNET_DISCONNECTED/, fn ->
        ChromicPDF.print_to_pdf({:url, "https://example.net"})
      end
    end
  end

  describe "a cookie can be set when printing" do
    @cookie %{
      name: "foo",
      value: "bar",
      domain: "localhost"
    }

    defmodule CookieEcho do
      use Plug.Router

      plug(:fetch_cookies)
      plug(:match)
      plug(:dispatch)

      get "/" do
        send_resp(conn, 200, inspect(conn.req_cookies))
      end
    end

    setup do
      start_supervised!({ChromicPDF, offline: false})

      start_supervised!(
        {Plug.Cowboy, scheme: :http, plug: CookieEcho, options: [port: @test_server_port]}
      )

      :ok
    end

    test "cookies can be set thru print_to_pdf/2 and are cleared afterwards" do
      input = {:url, "http://localhost:#{@test_server_port}/"}

      print_to_pdf(input, [set_cookie: @cookie], fn text ->
        assert text =~ ~s(%{"foo" => "bar"})
      end)

      print_to_pdf(input, [], fn text ->
        assert text =~ "%{}"
      end)
    end
  end

  describe "session pool timeout" do
    setup do
      start_supervised!({ChromicPDF, session_pool: [timeout: 1]})
      :ok
    end

    test "can be configured and generates a nice error messages" do
      assert_raise RuntimeError, ~r/Timeout in Channel.run_protocol/, fn ->
        print_to_pdf(fn _output -> :ok end)
      end
    end
  end
end
