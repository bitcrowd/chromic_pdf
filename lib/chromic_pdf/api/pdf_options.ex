# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.PDFOptions do
  @moduledoc false

  require EEx
  import ChromicPDF.Utils, only: [rendered_to_binary: 1]

  def prepare_input_options(source, opts) do
    opts
    |> put_source(source)
    |> replace_wait_for_with_evaluate()
    |> stringify_map_keys()
    |> sanitize_binaries()
  end

  defp put_source(opts, {:file, source}), do: put_source(opts, {:url, source})
  defp put_source(opts, {:path, source}), do: put_source(opts, {:url, source})
  defp put_source(opts, {:html, source}), do: put_source(opts, :html, source)

  defp put_source(opts, {:plug, plug_opts}) do
    if Keyword.has_key?(opts, :set_cookie) do
      raise "plug source conflicts with set_cookie"
    end

    {url, plug_opts} = Keyword.pop!(plug_opts, :url)

    set_cookie_opts =
      plug_opts
      |> ChromicPDF.Plug.start_agent_and_get_cookie()
      |> Map.put(:url, url)
      |> Map.put(:secure, String.starts_with?(url, "https"))

    opts
    |> Keyword.put(:set_cookie, set_cookie_opts)
    |> put_source(:url, url)
  end

  defp put_source(opts, {:url, source}) do
    url =
      if File.exists?(source) do
        # This works for relative paths as "local" Chromiums start with the same pwd.
        "file://#{Path.expand(source)}"
      else
        source
      end

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
    case Keyword.pop(opts, :wait_for) do
      {nil, opts} -> opts
      {wait_for, opts} -> do_replace_wait_for_with_evaluate(opts, wait_for)
    end
  end

  defp do_replace_wait_for_with_evaluate(opts, %{selector: selector, attribute: attribute}) do
    wait_for_script = render_wait_for_script(selector, attribute)

    Keyword.update(opts, :evaluate, %{expression: wait_for_script}, fn evaluate ->
      Map.update!(evaluate, :expression, fn user_script ->
        """
        #{user_script}
        #{wait_for_script}
        """
      end)
    end)
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

  @binary_options [
    [:html],
    [:print_to_pdf, "headerTemplate"],
    [:print_to_pdf, "footerTemplate"]
  ]

  defp sanitize_binaries(opts) do
    Enum.reduce(@binary_options, opts, fn path, acc ->
      update_in(acc, path, fn
        nil -> ""
        other -> rendered_to_binary(other)
      end)
    end)
  end
end
