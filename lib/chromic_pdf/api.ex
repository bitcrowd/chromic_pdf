defmodule ChromicPDF.API do
  @moduledoc false

  import ChromicPDF.{Telemetry, Utils}

  # credo:disable-for-next-line Credo.Check.Readability.AliasOrder
  alias ChromicPDF.{
    Browser,
    CaptureScreenshot,
    CloseStream,
    GhostscriptPool,
    PDFOptions,
    PDFAOptions,
    PrintToPDF,
    PrintToPDFAsStream,
    ReadFromStream
  }

  @spec print_to_pdf(
          ChromicPDF.Supervisor.services(),
          ChromicPDF.source() | ChromicPDF.source_and_options(),
          [ChromicPDF.pdf_option() | ChromicPDF.output_option()]
        ) :: ChromicPDF.return()
  def print_to_pdf(services, %{source: source, opts: opts}, overrides)
      when tuple_size(source) == 2 and is_list(opts) and is_list(overrides) do
    print_to_pdf(services, source, Keyword.merge(opts, overrides))
    print_to_pdf(services, source, Keyword.merge(opts, overrides))
  end

  def print_to_pdf(services, source, opts) when tuple_size(source) == 2 and is_list(opts) do
    chrome_export(services, :print_to_pdf, source, opts)
  end

  @spec print_to_pdf_as_stream(
          ChromicPDF.Supervisor.services(),
          input :: ChromicPDF.source() | ChromicPDF.source_and_options(),
          fun :: ChromicPDF.stream_function(),
          opts :: [ChromicPDF.pdf_option()]
        ) :: {:ok, ChromicPDF.stream_function_result()}
  def print_to_pdf_as_stream(services, %{source: source, opts: opts}, stream_fun, overrides)
      when tuple_size(source) == 2 and is_list(opts) and is_function(stream_fun) and
             is_list(overrides) do
    print_to_pdf_as_stream(services, source, stream_fun, Keyword.merge(opts, overrides))
  end

  def print_to_pdf_as_stream(services, source, stream_fun, opts)
      when tuple_size(source) == 2 and is_function(stream_fun) and is_list(opts) do
    %{browser: browser} = services

    opts = PDFOptions.prepare_export_options(:print_to_pdf_as_stream, source, opts)

    Browser.checkout_session(browser, fn session ->
      stream =
        Stream.resource(
          fn ->
            {:ok, handle} = Browser.run_protocol(browser, session, PrintToPDFAsStream, opts)

            %{"handle" => handle}
          end,
          fn stream ->
            case Browser.run_protocol(browser, session, ReadFromStream, stream) do
              {:ok, %{"data" => data, "eof" => false}} ->
                {[data], stream}

              {:ok, %{"data" => "", "eof" => true}} ->
                {:halt, stream}
            end
          end,
          fn stream ->
            {:ok, _} = Browser.run_protocol(browser, session, CloseStream, stream)
          end
        )

      {:ok, stream_fun.(stream)}
    end)
  end

  @spec capture_screenshot(ChromicPDF.Supervisor.services(), ChromicPDF.source(), [
          ChromicPDF.capture_screenshot_option() | ChromicPDF.output_option()
        ]) ::
          ChromicPDF.return()
  def capture_screenshot(services, source, opts) when tuple_size(source) == 2 and is_list(opts) do
    chrome_export(services, :capture_screenshot, source, opts)
  end

  @export_protocols %{
    capture_screenshot: CaptureScreenshot,
    print_to_pdf: PrintToPDF
  }

  defp chrome_export(services, protocol, source, opts)
       when tuple_size(source) == 2 and is_list(opts) do
    opts = PDFOptions.prepare_export_options(protocol, source, opts)

    with_telemetry(protocol, opts, fn ->
      Browser.checkout_session(services.browser, fn session ->
        services.browser
        |> Browser.run_protocol(session, Map.fetch!(@export_protocols, protocol), opts)
        |> PDFOptions.feed_chrome_data_into_output(opts)
      end)
    end)
  end

  @spec convert_to_pdfa(ChromicPDF.Supervisor.services(), ChromicPDF.path(), [
          ChromicPDF.pdfa_option() | ChromicPDF.output_option()
        ]) ::
          ChromicPDF.return()
  def convert_to_pdfa(services, pdf_path, opts) when is_binary(pdf_path) and is_list(opts) do
    with_tmp_dir(fn tmp_dir ->
      do_convert_to_pdfa(services, pdf_path, opts, tmp_dir)
    end)
  end

  @spec print_to_pdfa(
          ChromicPDF.Supervisor.services(),
          ChromicPDF.source() | ChromicPDF.source_and_options(),
          [
            ChromicPDF.pdf_option() | ChromicPDF.pdfa_option() | ChromicPDF.output_option()
          ]
        ) ::
          ChromicPDF.return()
  def print_to_pdfa(services, %{source: source, opts: opts}, overrides)
      when tuple_size(source) == 2 and is_list(opts) and is_list(overrides) do
    print_to_pdfa(services, source, Keyword.merge(opts, overrides))
  end

  def print_to_pdfa(services, source, opts) when tuple_size(source) == 2 and is_list(opts) do
    with_tmp_dir(fn tmp_dir ->
      pdf_path = Path.join(tmp_dir, random_file_name(".pdf"))
      :ok = print_to_pdf(services, source, Keyword.put(opts, :output, pdf_path))
      do_convert_to_pdfa(services, pdf_path, opts, tmp_dir)
    end)
  end

  defp do_convert_to_pdfa(services, pdf_path, opts, tmp_dir) do
    pdfa_path = Path.join(tmp_dir, random_file_name(".pdf"))

    with_telemetry(:convert_to_pdfa, opts, fn ->
      :ok = GhostscriptPool.convert(services.ghostscript_pool, pdf_path, opts, pdfa_path)
      PDFAOptions.feed_ghostscript_file_into_output(pdfa_path, opts)
    end)
  end
end
