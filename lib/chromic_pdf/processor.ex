defmodule ChromicPDF.Processor do
  @moduledoc false

  import ChromicPDF.Utils
  alias ChromicPDF.{CaptureScreenshot, GhostscriptPool, PrintToPDF, SessionPool}

  @type url :: binary()
  @type path :: binary()
  @type blob :: binary()

  @type source :: {:url, url()} | {:html, blob()}

  @type output_option :: {:output, binary()} | {:output, function()}
  @type pdf_option :: {:print_to_pdf, map()} | {:offline, boolean()} | output_option()
  @type pdfa_option ::
          {:pdfa_version, binary()} | {:pdfa_def_ext, binary()} | {:info, map()} | output_option()
  @type screenshot_option :: {:capture_screenshot, map()} | output_option()

  @spec print_to_pdf(module(), source(), [pdf_option()]) :: :ok | {:ok, blob()}
  def print_to_pdf(chromic, source, opts) when tuple_size(source) == 2 and is_list(opts) do
    chromic
    |> SessionPool.run_protocol(
      PrintToPDF,
      opts
      |> Keyword.put_new(:offline, true)
      |> merge_source_into_opts(source)
    )
    |> feed_chrome_data_into_output(opts)
  end

  @spec capture_screenshot(module(), source(), [screenshot_option()]) :: :ok | {:ok, blob()}
  def capture_screenshot(chromic, source, opts) when tuple_size(source) == 2 and is_list(opts) do
    chromic
    |> SessionPool.run_protocol(
      CaptureScreenshot,
      merge_source_into_opts(opts, source)
    )
    |> feed_chrome_data_into_output(opts)
  end

  defp merge_source_into_opts(opts, {source_type, source}) do
    Keyword.merge(
      opts,
      [
        {:source_type, source_type},
        {source_type, source}
      ]
    )
  end

  defp feed_chrome_data_into_output(data, opts) do
    case Keyword.get(opts, :output) do
      path when is_binary(path) ->
        File.write!(path, Base.decode64!(data))
        :ok

      fun when is_function(fun, 1) ->
        with_tmp_dir(fn tmp_dir ->
          path = Path.join(tmp_dir, random_file_name(".pdf"))
          File.write!(path, Base.decode64!(data))
          fun.(path)
        end)

        :ok

      nil ->
        {:ok, data}
    end
  end

  @spec convert_to_pdfa(module(), path :: binary(), [pdfa_option()]) :: :ok | {:ok, blob()}
  def convert_to_pdfa(chromic, pdf_path, opts) when is_binary(pdf_path) and is_list(opts) do
    with_tmp_dir(fn tmp_dir ->
      do_convert_to_pdfa(chromic, pdf_path, opts, tmp_dir)
    end)
  end

  @spec print_to_pdfa(module(), source(), [pdf_option() | pdfa_option()]) ::
          :ok | {:ok, blob()}
  def print_to_pdfa(chromic, source, opts) when tuple_size(source) == 2 and is_list(opts) do
    with_tmp_dir(fn tmp_dir ->
      pdf_path = Path.join(tmp_dir, random_file_name(".pdf"))
      :ok = print_to_pdf(chromic, source, Keyword.put(opts, :output, pdf_path))
      do_convert_to_pdfa(chromic, pdf_path, opts, tmp_dir)
    end)
  end

  defp do_convert_to_pdfa(chromic, pdf_path, opts, tmp_dir) do
    pdfa_path = Path.join(tmp_dir, random_file_name(".pdf"))
    :ok = GhostscriptPool.convert(chromic, pdf_path, opts, pdfa_path)

    case Keyword.get(opts, :output) do
      path when is_binary(path) ->
        File.cp!(pdfa_path, path)
        :ok

      fun when is_function(fun, 1) ->
        fun.(pdfa_path)
        :ok

      nil ->
        data =
          pdfa_path
          |> File.read!()
          |> Base.encode64()

        {:ok, data}
    end
  end
end
