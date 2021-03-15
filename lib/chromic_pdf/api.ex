defmodule ChromicPDF.API do
  @moduledoc false

  import ChromicPDF.Utils
  require EEx
  alias ChromicPDF.{Browser, CaptureScreenshot, ChromeError, GhostscriptPool, PrintToPDF}

  @spec print_to_pdf(
          ChromicPDF.Supervisor.services(),
          ChromicPDF.source() | ChromicPDF.source_and_options(),
          [ChromicPDF.pdf_option()]
        ) :: ChromicPDF.return()
  def print_to_pdf(services, %{source: source, opts: opts}, overrides)
      when tuple_size(source) == 2 and is_list(opts) and is_list(overrides) do
    print_to_pdf(services, source, Keyword.merge(opts, overrides))
  end

  def print_to_pdf(services, source, opts) when tuple_size(source) == 2 and is_list(opts) do
    chrome_export(services, :print_to_pdf, source, opts)
  end

  @spec capture_screenshot(ChromicPDF.Supervisor.services(), ChromicPDF.source(), [
          ChromicPDF.capture_screenshot_option()
        ]) ::
          ChromicPDF.return()
  def capture_screenshot(services, source, opts) when tuple_size(source) == 2 and is_list(opts) do
    chrome_export(services, :capture_screenshot, source, opts)
  end

  @export_protocols %{
    capture_screenshot: CaptureScreenshot,
    print_to_pdf: PrintToPDF
  }

  defp chrome_export(services, protocol, source, opts) do
    opts =
      opts
      |> put_source(source)
      |> replace_wait_for_with_evaluate()
      |> stringify_map_keys()
      |> iolists_to_binary()

    with_telemetry(protocol, opts, fn ->
      services.browser
      |> Browser.run_protocol(Map.fetch!(@export_protocols, protocol), opts)
      |> feed_chrome_data_into_output(opts)
    end)
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

  EEx.function_from_string(
    :defp,
    :render_wait_for_script,
    """
    const waitForAttribute = async (selector, attribute) => {
      while (!document.querySelector(selector).hasAttribute(attribute)) {
        await new Promise(resolve => requestAnimationFrame(resolve));
      }
    };

    waitForAttribute('<%= selector %>', '<%= attribute %>');
    """,
    [:selector, :attribute]
  )

  defp replace_wait_for_with_evaluate(opts) do
    opts
    |> Keyword.pop(:wait_for)
    |> do_replace_wait_for_with_evaluate()
  end

  defp do_replace_wait_for_with_evaluate({nil, opts}), do: opts

  defp do_replace_wait_for_with_evaluate({%{selector: selector, attribute: attribute}, opts}) do
    if Keyword.has_key?(opts, :evaluate) do
      raise("wait_for option cannot be combined with evaluate option")
    end

    expression = render_wait_for_script(selector, attribute)

    Keyword.put(opts, :evaluate, %{expression: expression})
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

  defp feed_chrome_data_into_output({:error, error}, _opts) do
    raise ChromeError, code: error
  end

  defp feed_chrome_data_into_output({:ok, data}, opts) do
    case Keyword.get(opts, :output) do
      path when is_binary(path) ->
        File.write!(path, Base.decode64!(data))
        :ok

      fun when is_function(fun, 1) ->
        result_from_callback =
          with_tmp_dir(fn tmp_dir ->
            path = Path.join(tmp_dir, random_file_name(".pdf"))
            File.write!(path, Base.decode64!(data))
            fun.(path)
          end)

        {:ok, result_from_callback}

      nil ->
        {:ok, data}
    end
  end

  @spec convert_to_pdfa(ChromicPDF.Supervisor.services(), ChromicPDF.path(), [
          ChromicPDF.pdfa_option()
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
            ChromicPDF.pdf_option() | ChromicPDF.pdfa_option()
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

      case Keyword.get(opts, :output) do
        path when is_binary(path) ->
          File.cp!(pdfa_path, path)
          :ok

        fun when is_function(fun, 1) ->
          {:ok, fun.(pdfa_path)}

        nil ->
          data =
            pdfa_path
            |> File.read!()
            |> Base.encode64()

          {:ok, data}
      end
    end)
  end

  defp with_telemetry(operation, opts, fun) do
    metadata = Keyword.get(opts, :telemetry_metadata, %{})

    :telemetry.span([:chromic_pdf, operation], metadata, fn ->
      {fun.(), metadata}
    end)
  end
end
