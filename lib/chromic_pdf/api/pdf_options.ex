defmodule ChromicPDF.PDFOptions do
  @moduledoc false

  import ChromicPDF.Utils
  require EEx
  alias ChromicPDF.ChromeError

  def prepare_export_options(source, opts) do
    opts
    |> put_source(source)
    |> replace_wait_for_with_evaluate()
    |> stringify_map_keys()
    |> iolists_to_binary()
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

  def feed_chrome_data_into_output({:error, error}, opts) do
    raise ChromeError, error: error, opts: opts
  end

  def feed_chrome_data_into_output({:ok, data}, opts) do
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
end
