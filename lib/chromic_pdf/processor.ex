defmodule ChromicPDF.Processor do
  @moduledoc false

  import ChromicPDF.Utils
  alias ChromicPDF.{GhostscriptPool, SessionPool}

  @type url :: binary()
  @type path :: binary()
  @type blob :: binary()

  @type source :: {:url, url()} | {:html, blob()}

  @type output_option :: {:output, binary()} | {:output, function()}
  @type pdf_option :: {:print_to_pdf, map()} | output_option()
  @type pdfa_option ::
          {:pdfa_version, binary()} | {:pdfa_def_ext, binary()} | {:info, map()} | output_option()

  @spec print_to_pdf(module(), source(), [pdf_option()]) :: :ok | {:ok, blob()}
  def print_to_pdf(chromic, source, opts) when tuple_size(source) == 2 and is_list(opts) do
    data = SessionPool.print_to_pdf(chromic, source, opts)
    feed_chrome_data_into_output(data, opts)
  end

  @spec capture_screenshot(module(), source(), keyword()) :: :ok | {:ok, blob()}
  def capture_screenshot(chromic, source, opts) when tuple_size(source) == 2 and is_list(opts) do
    data = SessionPool.capture_screenshot(chromic, source, opts)
    feed_chrome_data_into_output(data, opts)
  end

  defp feed_chrome_data_into_output(data, opts) do
    case Keyword.get(opts, :output) do
      path when is_binary(path) ->
        File.write!(path, Base.decode64!(data))
        :ok

      fun when is_function(fun, 1) ->
        fun.(data)
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
