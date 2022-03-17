defmodule ChromicPDF.Template do
  @moduledoc """
  Helper functions for page styling.

  For a start, see `source_and_options/1`.

  ## Motivation

  This module contains helper functions that make it easier to to build HTML templates (body,
  header, and footer) that fully cover a given page. Like an adapter, it tries to harmonize
  Chrome's `printToPDF` options and related CSS layout styles (`@page` and friends) with a custom
  set of page sizing options. Using this module is entirely optional, but perhaps can help to
  avoid some common pitfalls arising from the slightly unintuitive and sometimes conflicting
  behaviour of `printToPDF` options and `@page` CSS styles in Chrome.


  ## Page dimensions

  One particularly cumbersome detail is that Chrome in headless mode does not correctly interpret
  the `@page` CSS rule to configure the page dimensions. Resulting PDF files will always be in
  US-letter format unless configured differently with the `paperWidth` and `paperHeight` options.
  Experience has shown, that results will be best if the `@page` rule aligns with the values
  passed to `printToPDF/2`, which is why this module exists to make basic page sizing easier.

  To rotate a page into landscape, use the `landscape` option.
  """

  require EEx

  @type blob :: binary()

  @type content_option ::
          {:content, blob()}
          | {:header, blob()}
          | {:footer, blob()}

  @type paper_size ::
          {float(), float()}
          | :a0
          | :a1
          | :a2
          | :a3
          | :a4
          | :a5
          | :a6
          | :a7
          | :a8
          | :a9
          | :a10
          | :us_letter
          | :legal
          | :tabloid

  @type style_option ::
          {:size, paper_size()}
          | {:header_height, binary()}
          | {:header_font_size, binary()}
          | {:header_zoom, binary()}
          | {:footer_height, binary()}
          | {:footer_font_size, binary()}
          | {:footer_zoom, binary()}
          | {:webkit_print_color_adjust, binary()}
          | {:landscape, boolean()}

  @paper_sizes_in_inch %{
    a0: {33.1, 46.8},
    a1: {23.4, 33.1},
    a2: {16.5, 23.4},
    a3: {11.7, 16.5},
    a4: {8.3, 11.7},
    a5: {5.8, 8.3},
    a6: {4.1, 5.8},
    a7: {2.9, 4.1},
    a8: {2.0, 2.9},
    a9: {1.5, 2.0},
    a10: {1.0, 1.5},
    us_letter: {8.5, 11.0},
    legal: {8.5, 14.0},
    tabloid: {11.0, 17.0}
  }

  @default_paper_name :us_letter
  @default_paper_size Map.fetch!(@paper_sizes_in_inch, @default_paper_name)

  @default_content """
  <style>
    body {
      margin: 1em;
      font-family: sans-serif;
    }

    h1 {
      margin: 1em 0;
      font-size: 22pt;
    }

    h2 {
      margin: 1em 0;
      font-size: 14pt;
    }

    p { font-size: 12pt; }

    pre {
      padding: 1em;
      border: 1px solid grey;
      border-radius: 2px;
      background-color: #faffa3;
      white-space: pre-wrap;
    }
  </style>

  <h1>ChromicPDF</h1>
  <p>Please see documentation at <a href="https://hexdocs.pm/chromic_pdf/ChromicPDF.html">hexdocs.pm</a></p>

  <h2>User Agent</h2>
  <pre id="user-agent"></pre>

  <script type="text/javascript">
  window.onload = function() {
    var browser, userAgent = navigator.userAgent;
    document.getElementById('user-agent').innerHTML = userAgent;
  };
  </script>
  """

  @doc """
  Returns source and options for a PDF to be printed, a given set of template options. The return
  value can be passed to `ChromicPDF.print_to_pdf/2`.

  ## Options

  * `header`
  * `footer`
  * all options from `styles/1`

  ## Example

  This example has the dimension of a ISO A4 page.

      ChromicPDF.Template.source_and_options(
        content: "<p>Hello</p>",
        header: "<p>header</p>",
        footer: "<p>footer</p>",
        size: :a4,
        header_height: "45mm",
        header_font_size: "20pt",
        footer_height: "40mm"
      )

  Content, header, and footer templates should be unwrapped HTML markup (i.e. no `<html>` around
  the content), prefixed with any `<style>` tags that your page needs.

        <style>
          h1 { font-size: 22pt; }
        </style>
        <h1>Hello</h1>

  ## ⚠ Markup is injected into the DOM ⚠

  Please be aware that the options returned by this function cause ChromicPDF to inject the
  markup directly into the DOM using the remote debugging API. This comes with some pitfalls
  which are explained in `ChromicPDF.print_to_pdf/2`. Most notably, **no relative URLs** may be
  used within the given HTML.
  """
  @spec source_and_options([content_option() | style_option()]) ::
          ChromicPDF.source_and_options()
  def source_and_options(opts) do
    content = Keyword.get(opts, :content, @default_content)
    header = Keyword.get(opts, :header, "")
    footer = Keyword.get(opts, :footer, "")
    styles = do_styles(opts)

    {width, height} = get_paper_size(opts)

    %{
      source: {:html, html_concat(styles, content)},
      opts: [
        print_to_pdf: %{
          displayHeaderFooter: true,
          headerTemplate: html_concat(styles, header),
          footerTemplate: html_concat(styles, footer),
          paperWidth: width,
          paperHeight: height
        }
      ]
    }
  end

  @doc """
  Concatenes two HTML strings or iolists into one.

  From `{:safe, iolist}` tuples, the `:safe` is dropped. This is useful to prepare data coming
  from a Phoenix-compiled `.eex` template.

      content = html_concat(@styles, render("content.html"))
  """
  @spec html_concat({:safe, iolist()} | iodata(), {:safe, iolist()} | iodata()) :: iolist()
  def html_concat({:safe, styles}, content), do: html_concat(styles, content)
  def html_concat(styles, {:safe, content}), do: html_concat(styles, content)
  def html_concat(styles, content), do: [styles, content]

  @styles """
  <style>
    * {
      -webkit-print-color-adjust: <%= @webkit_print_color_adjust %>;
    }

    @page {
      width: <%= @width %>;
      height: <%= @height %>;
      margin: <%= @header_height %> 0 <%= @footer_height %>;
    }

    #header {
      padding: 0 !important;
      height: <%= @header_height %>;
      font-size: <%= @header_font_size %>;
      zoom: <%= @header_zoom %>;
    }

    #footer {
      padding: 0 !important;
      height: <%= @footer_height %>;
      font-size: <%= @footer_font_size %>;
      zoom: <%= @footer_zoom %>;
    }

    html, body {
      margin: 0;
      padding: 0;
    }
  </style>
  """

  @doc """
  Renders page styles for given options.

  These base styles will configure page dimensions and header and footer heights. They also
  remove any browser padding and margins from these elements, and set the font-size.

  Additionally, they set the zoom level of header and footer templates to 0.75 which seems to
  make them align with the content viewport scaling better.

  ## Options

  * `size` page size, either a standard name (`:a4`, `:us_letter`) or a
     `{<width>, <height>}` tuple in inches, default: `:us_letter`
  * `header_height` default: zero
  * `header_font_size` default: 10pt
  * `header_zoom` default: 0.75
  * `footer_height` default: zero
  * `footer_font_size` default: 10pt
  * `footer_zoom` default: 0.75
  * `webkit_color_print_adjust` default: "exact"
  * `landscape` default: false

  ## Landscape

  As it turns out, Chrome does not recognize the `landscape` option in its `printToPDF` command
  when explicit page dimensions are given. Hence, we provide a `landscape` option here that
  swaps the page dimensions (e.g. it turns 11.7x8.3" A4 into 8.3"x11.7").
  """
  @spec styles([style_option()]) :: blob()
  def styles(opts \\ []), do: do_styles(opts)

  defp do_styles(opts) do
    {width, height} = get_paper_size(opts)

    assigns = [
      width: "#{width}in",
      height: "#{height}in",
      header_height: Keyword.get(opts, :header_height, "0"),
      header_font_size: Keyword.get(opts, :header_font_size, "10pt"),
      footer_height: Keyword.get(opts, :footer_height, "0"),
      footer_font_size: Keyword.get(opts, :footer_font_size, "10pt"),
      header_zoom: Keyword.get(opts, :header_zoom, "0.75"),
      footer_zoom: Keyword.get(opts, :footer_zoom, "0.75"),
      webkit_print_color_adjust: Keyword.get(opts, :webkit_print_color_adjust, "exact")
    ]

    render_styles(assigns)
  end

  EEx.function_from_string(:defp, :render_styles, @styles, [:assigns])

  # Inverts the paper size if landscape orientation.
  defp maybe_rotate_paper(size, false) when tuple_size(size) === 2, do: size
  defp maybe_rotate_paper({w, h}, true), do: {h, w}

  # Fetches paper size from opts, translates from config or uses given {width, height} tuple.
  defp get_paper_size(manual) when tuple_size(manual) === 2, do: manual

  defp get_paper_size(name) when is_atom(name) do
    @paper_sizes_in_inch
    |> Map.get(name, @default_paper_size)
  end

  defp get_paper_size(opts) when is_list(opts) do
    opts
    |> Keyword.get(:size, @default_paper_size)
    |> get_paper_size()
    |> maybe_rotate_paper(Keyword.get(opts, :landscape, false))
  end
end
