# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.API do
  @moduledoc false

  import ChromicPDF.{Telemetry, Utils}

  # credo:disable-for-next-line Credo.Check.Readability.AliasOrder
  alias ChromicPDF.{
    Browser,
    CaptureScreenshot,
    GhostscriptPool,
    PDFOptions,
    PDFAOptions,
    PrintToPDF
  }

  @spec print_to_pdf(
          ChromicPDF.Supervisor.services(),
          ChromicPDF.source() | ChromicPDF.source_and_options(),
          [ChromicPDF.pdf_option() | ChromicPDF.export_option()]
        ) :: ChromicPDF.export_return()
  def print_to_pdf(services, %{source: source, opts: opts}, overrides)
      when tuple_size(source) == 2 and is_list(opts) and is_list(overrides) do
    print_to_pdf(services, source, Keyword.merge(opts, overrides))
  end

  def print_to_pdf(services, source, opts) when tuple_size(source) == 2 and is_list(opts) do
    chrome_export(services, :print_to_pdf, source, opts)
  end

  def print_to_pdf_and_merge(services, sources, opts) when is_list(sources) and is_list(opts) do
    with_tmp_dir(fn tmp_dir ->
      sources = merge_print_options(sources, opts)

      pdf_path_list = print_multiple_to_pdf(services, sources, tmp_dir, opts)

      merge_tmp_path = Path.join(tmp_dir, random_file_name(".pdf"))

      :ok = GhostscriptPool.merge(services.ghostscript_pool, pdf_path_list, opts, merge_tmp_path)
      PDFOptions.feed_merge_data_into_output(merge_tmp_path, opts)
    end)
  end

  @spec capture_screenshot(ChromicPDF.Supervisor.services(), ChromicPDF.source(), [
          ChromicPDF.capture_screenshot_option() | ChromicPDF.export_option()
        ]) ::
          ChromicPDF.export_return()
  def capture_screenshot(services, source, opts) when tuple_size(source) == 2 and is_list(opts) do
    chrome_export(services, :capture_screenshot, source, opts)
  end

  @export_protocols %{
    capture_screenshot: CaptureScreenshot,
    print_to_pdf: PrintToPDF
  }

  @margin_opts [:marginTop, :marginBottom, :marginLeft, :marginRight]

  defp merge_print_options(sources, opts) when is_list(sources) do
    Enum.map(sources, &merge_print_options(&1, opts))
  end

  defp merge_print_options(%{opts: [print_to_pdf: single_opts] = source_opts} = source, opts) do
    general_print_opts = Keyword.get(opts, :print_to_pdf, %{})

    merged_opts =
      Map.merge(general_print_opts, single_opts, fn
        k, v1, nil when k in @margin_opts -> v1
        _k, _v1, v2 -> v2
      end)

    new_source_opts = Keyword.put(source_opts, :print_to_pdf, merged_opts)

    %{source | opts: new_source_opts}
  end

  defp merge_print_options(source, opts) do
    general_print_opts = Keyword.get(opts, :print_to_pdf, %{})

    %{source: source, opts: general_print_opts}
  end

  defp print_multiple_to_pdf(services, sources, tmp_dir, opts) do
    Enum.map(sources, fn
      %{source: source, opts: opts} ->
        tmp_path = Path.join(tmp_dir, random_file_name(".pdf"))
        opts = Keyword.put(opts, :output, tmp_path)

        chrome_export(services, :print_to_pdf, source, opts)

        tmp_path

      source when tuple_size(source) == 2 ->
        tmp_path = Path.join(tmp_dir, random_file_name(".pdf"))
        opts = Keyword.put(opts, :output, tmp_path)

        chrome_export(services, :print_to_pdf, source, opts)

        tmp_path
    end)
  end

  defp chrome_export(services, protocol, source, opts) do
    opts = PDFOptions.prepare_export_options(source, opts)

    with_telemetry(protocol, opts, fn ->
      services.browser
      |> Browser.run_protocol(Map.fetch!(@export_protocols, protocol), opts)
      |> PDFOptions.feed_chrome_data_into_output(opts)
    end)
  end

  @spec convert_to_pdfa(ChromicPDF.Supervisor.services(), ChromicPDF.path(), [
          ChromicPDF.pdfa_option() | ChromicPDF.export_option()
        ]) ::
          ChromicPDF.export_return()
  def convert_to_pdfa(services, pdf_path, opts) when is_binary(pdf_path) and is_list(opts) do
    with_tmp_dir(fn tmp_dir ->
      do_convert_to_pdfa(services, pdf_path, opts, tmp_dir)
    end)
  end

  @spec print_to_pdfa(
          ChromicPDF.Supervisor.services(),
          ChromicPDF.source() | ChromicPDF.source_and_options(),
          [
            ChromicPDF.pdf_option() | ChromicPDF.pdfa_option() | ChromicPDF.export_option()
          ]
        ) ::
          ChromicPDF.export_return()
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

  @spec merge(ChromicPDF.Supervisor.services(), list(ChromicPDF.path()), keyword()) ::
          ChromicPDF.return()
  def merge(services, pdf_path_list, opts) do
    with_tmp_dir(fn tmp_dir ->
      tmp_path = Path.join(tmp_dir, random_file_name(".pdf"))

      :ok = GhostscriptPool.merge(services.ghostscript_pool, pdf_path_list, opts, tmp_path)
      PDFAOptions.feed_ghostscript_file_into_output(tmp_path, opts)
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
