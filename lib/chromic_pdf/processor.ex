defmodule ChromicPDF.Processor do
  @moduledoc false

  import ChromicPDF.Utils
  alias ChromicPDF.{CaptureScreenshot, GhostscriptPool, PrintToPDF, SessionPool}

  @type url :: binary()
  @type path :: binary()
  @type blob :: iodata()

  @type source :: {:url, url()} | {:html, blob()}
  @type source_and_options :: %{source: source(), opts: [pdf_option()]}
  @type return :: :ok | {:ok, binary()}

  @type output_option :: {:output, binary()} | {:output, function()}

  @type pdf_option ::
          {:print_to_pdf, map()}
          | {:set_cookie, map()}
          | output_option()

  @type pdfa_option ::
          {:pdfa_version, binary()}
          | {:pdfa_def_ext, binary()}
          | {:info, map()}
          | output_option()
  @type screenshot_option :: {:capture_screenshot, map()} | output_option()

  @spec print_to_pdf(module(), source() | source_and_options(), [pdf_option()]) :: return()
  def print_to_pdf(chromic, %{source: source, opts: opts}, overrides)
      when tuple_size(source) == 2 and is_list(opts) and is_list(overrides) do
    print_to_pdf(chromic, source, Keyword.merge(opts, overrides))
  end

  def print_to_pdf(chromic, source, opts) when tuple_size(source) == 2 and is_list(opts) do
    chrome_export(chromic, PrintToPDF, source, opts)
  end

  @spec capture_screenshot(module(), source(), [screenshot_option()]) :: return()
  def capture_screenshot(chromic, source, opts) when tuple_size(source) == 2 and is_list(opts) do
    chrome_export(chromic, CaptureScreenshot, source, opts)
  end

  defp chrome_export(chromic, protocol, source, opts) do
    opts =
      opts
      |> put_source(source)
      |> stringify_map_keys()
      |> iolists_to_binary()

    chromic
    |> SessionPool.run_protocol(protocol, opts)
    |> feed_chrome_data_into_output(opts)
  end

  defp put_source(opts, {:file, source}), do: put_source(opts, {:url, source})
  defp put_source(opts, {:path, source}), do: put_source(opts, {:url, source})
  defp put_source(opts, {:html, source}), do: put_source(opts, :html, source)

  defp put_source(opts, {:url, source}) do
    url = if File.exists?(source), do: "file://#{Path.expand(source)}", else: source
    put_source(opts, :url, url)
  end

  defp put_source(opts, source_type, source) do
    opts
    |> Keyword.put_new(:source_type, source_type)
    |> Keyword.put_new(source_type, source)
  end

  @map_options [:print_to_pdf, :capture_screenshot]

  defp stringify_map_keys(opts) do
    Enum.reduce(@map_options, opts, fn key, acc ->
      Keyword.update(acc, key, %{}, &do_stringify_map_keys/1)
    end)
  end

  defp do_stringify_map_keys(map) do
    Enum.into(map, %{}, fn {k, v} -> {to_string(k), v} end)
  end

  @iolist_options [
    [:html],
    [:print_to_pdf, "headerTemplate"],
    [:print_to_pdf, "footerTemplate"]
  ]

  defp iolists_to_binary(opts) do
    Enum.reduce(@iolist_options, opts, fn path, acc ->
      update_in(acc, path, fn
        nil -> ""
        {:safe, value} -> :erlang.iolist_to_binary(value)
        value when is_list(value) -> :erlang.iolist_to_binary(value)
        value -> value
      end)
    end)
  end

  defp feed_chrome_data_into_output({:error, "net::ERR_INTERNET_DISCONNECTED"}, _opts) do
    raise("""
    net::ERR_INTERNET_DISCONNECTED

    This indicates you are trying to navigate to a remote URL without having enabled the "online
    mode". Please start ChromicPDF with the `offline: false` parameter.

        {ChromicPDF, offline: false}
    """)
  end

  defp feed_chrome_data_into_output({:error, error}, _opts) do
    raise(error)
  end

  defp feed_chrome_data_into_output({:ok, data}, opts) do
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

  @spec convert_to_pdfa(module(), path(), [pdfa_option()]) :: return()
  def convert_to_pdfa(chromic, pdf_path, opts) when is_binary(pdf_path) and is_list(opts) do
    with_tmp_dir(fn tmp_dir ->
      do_convert_to_pdfa(chromic, pdf_path, opts, tmp_dir)
    end)
  end

  @spec print_to_pdfa(module(), source(), [pdf_option() | pdfa_option()]) :: return()
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
