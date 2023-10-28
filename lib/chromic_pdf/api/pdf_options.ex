# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.PDFOptions do
  @moduledoc false

  require EEx

  def prepare_input_options(source, opts) do
    opts
    |> set_cookie_for_assigns_plug(source)
    |> put_source(source)
    |> replace_wait_for_with_evaluate()
    |> stringify_map_keys()
    |> iolists_to_binary()
  end

  defp set_cookie_for_assigns_plug(opts, source) do
    cond do
      !Keyword.has_key?(opts, :assigns) ->
        opts

      !match?({:url, _}, source) ->
        raise(":assigns option invalid with :url source")

      Keyword.has_key?(opts, :set_cookie) ->
        raise(":assigns option conflicts with :set_cookie")

      true ->
        do_set_cookie_for_assigns_plug(opts, source)
    end
  end

  defp do_set_cookie_for_assigns_plug(opts, {:url, url}) do
    {assigns, rest} = Keyword.pop(opts, :assigns)

    set_cookie_opts =
      assigns
      |> ChromicPDF.AssignsPlug.start_agent_and_get_cookie()
      |> Map.put(:url, url)

    Keyword.put(rest, :set_cookie, set_cookie_opts)
  end

  defp put_source(opts, {:file, source}), do: put_source(opts, {:url, source})
  defp put_source(opts, {:path, source}), do: put_source(opts, {:url, source})
  defp put_source(opts, {:html, source}), do: put_source(opts, :html, source)

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
end
