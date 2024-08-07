# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.API do
  @moduledoc false

  import ChromicPDF.{Telemetry, Utils}

  alias ChromicPDF.{
    Browser,
    CaptureScreenshot,
    ExportOptions,
    GhostscriptPool,
    PrintToPDF,
    ProtocolOptions
  }

  @spec print_to_pdf(
          ChromicPDF.Supervisor.services(),
          ChromicPDF.source() | [ChromicPDF.source()],
          [ChromicPDF.pdf_option() | ChromicPDF.shared_option()]
        ) :: ChromicPDF.result()
  def print_to_pdf(services, sources, opts) when is_list(sources) and is_list(opts) do
    with_tmp_dir(fn tmp_dir ->
      paths =
        Enum.map(sources, fn source ->
          tmp_path = Path.join(tmp_dir, random_file_name(".pdf"))
          :ok = print_to_pdf(services, source, Keyword.put(opts, :output, tmp_path))
          tmp_path
        end)

      output_path = Path.join(tmp_dir, random_file_name(".pdf"))

      with_telemetry(:join_pdfs, opts, fn ->
        :ok = GhostscriptPool.join(services.ghostscript_pool, paths, opts, output_path)
        ExportOptions.feed_file_into_output(output_path, opts)
      end)
    end)
  end

  def print_to_pdf(services, %{source: source, opts: opts}, overrides)
      when is_tuple(source) and is_list(opts) and is_list(overrides) do
    print_to_pdf(services, source, Keyword.merge(opts, overrides))
  end

  def print_to_pdf(services, source, opts) when is_tuple(source) and is_list(opts) do
    {protocol, opts} =
      opts
      |> ProtocolOptions.prepare_print_to_pdf_options(source)
      |> Keyword.pop(:protocol, PrintToPDF)

    chrome_export(services, :print_to_pdf, protocol, opts)
  end

  @spec capture_screenshot(ChromicPDF.Supervisor.services(), ChromicPDF.source(), [
          ChromicPDF.capture_screenshot_option() | ChromicPDF.shared_option()
        ]) ::
          ChromicPDF.result()
  def capture_screenshot(services, %{source: source, opts: opts}, overrides)
      when is_tuple(source) and is_list(opts) and is_list(overrides) do
    capture_screenshot(services, source, Keyword.merge(opts, overrides))
  end

  def capture_screenshot(services, source, opts) when is_tuple(source) and is_list(opts) do
    {protocol, opts} =
      opts
      |> ProtocolOptions.prepare_capture_screenshot_options(source)
      |> Keyword.pop(:protocol, CaptureScreenshot)

    chrome_export(services, :capture_screenshot, protocol, opts)
  end

  @spec run_protocol(ChromicPDF.Supervisor.services(), module(), [
          ChromicPDF.shared_option() | ChromicPDF.protocol_option()
        ]) :: ChromicPDF.result()
  def run_protocol(services, protocol, opts) when is_atom(protocol) and is_list(opts) do
    chrome_export(services, :run_protocol, protocol, opts)
  end

  defp chrome_export(services, operation, protocol, opts) do
    with_telemetry(operation, opts, fn ->
      services.browser
      |> Browser.new_protocol(protocol, opts)
      |> ExportOptions.feed_chrome_data_into_output(opts)
    end)
  end

  @spec convert_to_pdfa(ChromicPDF.Supervisor.services(), ChromicPDF.path(), [
          ChromicPDF.pdfa_option() | ChromicPDF.shared_option()
        ]) ::
          ChromicPDF.result()
  def convert_to_pdfa(services, pdf_path, opts) when is_binary(pdf_path) and is_list(opts) do
    with_tmp_dir(fn tmp_dir ->
      do_convert_to_pdfa(services, pdf_path, opts, tmp_dir)
    end)
  end

  @spec print_to_pdfa(
          ChromicPDF.Supervisor.services(),
          ChromicPDF.source() | [ChromicPDF.source()],
          [
            ChromicPDF.pdf_option() | ChromicPDF.pdfa_option() | ChromicPDF.shared_option()
          ]
        ) ::
          ChromicPDF.result()
  def print_to_pdfa(services, source, opts) when is_list(opts) do
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
      ExportOptions.feed_file_into_output(pdfa_path, opts)
    end)
  end
end
