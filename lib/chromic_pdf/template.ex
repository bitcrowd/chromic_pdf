# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.Template do
  @moduledoc """
  Helper functions for page styling.

  For a start, see `source_and_options/1`.

  ## Motivation

  This module contains helper functions that make it easier to to build HTML templates (body,
  header, and footer) that fully cover a given page. It tries to harmonize Chrome's `printToPDF`
  options and related CSS layout styles (`@page` and friends) with a custom set of page sizing
  options.

  Using this module is entirely optional, but perhaps can help to avoid some common pitfalls
  arising from the slightly unintuitive and sometimes conflicting behaviour of `printToPDF`
  options and `@page` CSS styles in Chrome.
  """

  import ChromicPDF.Utils, only: [semver_compare: 2]
  require EEx
  alias ChromicPDF.ChromeRunner

  @type content_option :: {:content, iodata()}

  @type header_footer_option :: {:header, iodata()} | {:footer, iodata()}

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
          | {:text_rendering, binary()}
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
  Returns source and options for a PDF to be printed, a given set of template options.

  The return value can be directly passed to `ChromicPDF.print_to_pdf/2`.

  ## Options

  * `content` iodata page content (required)
  * `header` iodata content of header (default: "")
  * `footer` iodata content of footer (default: "")
  * all options from `styles/1`

  ## Example

  This example has the dimension of a ISO A4 page.

      [
        content: "<p>Hello</p>",
        header: "<p>header</p>",
        footer: "<p>footer</p>",
        size: :a4,
        header_height: "45mm",
        header_font_size: "20pt",
        footer_height: "40mm"
      ]
      |> ChromicPDF.Template.source_and_options()
      |> ChromicPDF.print_to_pdf()

  Content, header, and footer templates should be unwrapped HTML markup (i.e. no `<html>` around
  the content), including any `<style>` tags that your page needs.

        <style>
          h1 { font-size: 22pt; }
        </style>
        <h1>Hello</h1>

  ## ⚠ Markup is injected into the DOM ⚠

  Please be aware that the "source" returned by this function cause ChromicPDF to inject the
  markup directly into the DOM using the remote debugging API. This comes with some pitfalls
  which are explained in `ChromicPDF.print_to_pdf/2`. Most notably, **no relative URLs** may be
  used within the given HTML.
  """
  @spec source_and_options([content_option() | header_footer_option() | style_option()]) ::
          ChromicPDF.source_and_options()
  def source_and_options(opts) do
    # Keep dialyzer happy by making sure we only pass on option keys as spec'd in lower funs.
    {content, opts} = Keyword.pop(opts, :content, @default_content)
    {header_and_footer_opts, style_opts} = Keyword.split(opts, [:header, :footer])

    %{
      source: {:html, html_concat(page_styles(style_opts), content)},
      opts: options(header_and_footer_opts ++ style_opts)
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

  @doc """
  Returns an options list for given template options.

  Returned options can be passed as second argument to `ChromicPDF.print_to_pdf/2`.

  ## Options

  * `header` iodata content of header
  * `footer` iodata content of footer
  * all options from `styles/1`

  ## Example

  This example has the dimension of a ISO A4 page.

      ChromicPDF.Template.options(
        header: "<p>header</p>",
        footer: "<p>footer</p>",
        size: :a4,
        header_height: "45mm",
        header_font_size: "20pt",
        footer_height: "40mm"
      )

  Header, and footer templates should be unwrapped HTML markup (i.e. no `<html>` around
  the content), including any `<style>` tags that your page needs.
  """
  @spec options() :: keyword()
  @spec options([header_footer_option() | style_option()]) :: keyword()
  def options(opts \\ []) do
    {header, opts} = Keyword.pop(opts, :header, "")
    {footer, opts} = Keyword.pop(opts, :footer, "")
    styles = header_footer_styles(opts)

    [
      print_to_pdf: %{
        preferCSSPageSize: true,
        displayHeaderFooter: true,
        headerTemplate: html_concat(styles, header),
        footerTemplate: html_concat(styles, footer)
      }
    ]
  end

  @page_styles """
  <style>
    * {
      -webkit-print-color-adjust: <%= @webkit_print_color_adjust %>;
      text-rendering: <%= @text_rendering %>;
    }

    @page {
      size: <%= @width %> <%= @height %>;
      margin: <%= @header_height %> 0 <%= @footer_height %>;
    }

    body {
      margin: 0;
      padding: 0;
    }
  </style>
  """

  @header_footer_styles """
  <style>
    * {
      -webkit-print-color-adjust: <%= @webkit_print_color_adjust %>;
      text-rendering: <%= @text_rendering %>;
    }

    #header {
      padding: 0 !important;
      height: <%= @header_height %>;
      font-size: <%= @header_font_size %>;
    }

    #footer {
      padding: 0 !important;
      height: <%= @footer_height %>;
      font-size: <%= @footer_font_size %>;
    }
  </style>
  """

  @doc """
  Renders page styles & header/footer styles in a single template.

  This function is deprecated. Since Chromium v117 the footer and header templates must not
  contain any margins in a `@page` directive anymore.

  See https://github.com/bitcrowd/chromic_pdf/issues/290 for details.

  Please use `page_styles/1` or `header_footer_styles/1` instead.
  """
  @deprecated "Use page_styles/1 or header_footer_styles/1 instead"
  @spec styles() :: binary()
  @spec styles([style_option()]) :: binary()
  def styles(opts \\ []) do
    page_styles(opts) <> header_footer_styles(opts)
  end

  @doc """
  Renders page styles for given template options.

  These base styles will configure page dimensions and apply margins for headers and footers.
  They also remove any default browser margin from the body, and apply sane defaults for
  rendering text in print.

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
  @spec page_styles() :: binary()
  #  @spec page_styles([style_option()]) :: binary()
  @spec page_styles(keyword) :: binary()
  def page_styles(opts \\ []) do
    opts
    |> assigns_for_styles()
    |> render_page_styles()
    |> squish()
  end

  EEx.function_from_string(:defp, :render_page_styles, @page_styles, [:assigns])

  @doc """
  Renders header/footer styles for given template options.

  These styles apply sane default to your header and footer templates. They set a default
  fonts-size and force their height.

  For Chromium before v120, they also set the zoom level of header and footer templates
  to 0.75 which aligns them with the content viewport scaling.

  https://bugs.chromium.org/p/chromium/issues/detail?id=1509917#c3
  """
  @spec header_footer_styles() :: binary()
  @spec header_footer_styles([style_option()]) :: binary()
  def header_footer_styles(opts \\ []) do
    opts
    |> assigns_for_styles()
    |> render_header_footer_styles()
    |> squish()
  end

  EEx.function_from_string(:defp, :render_header_footer_styles, @header_footer_styles, [:assigns])

  defp assigns_for_styles(opts) do
    {width, height} = get_paper_size(opts)

    [
      width: "#{width}in",
      height: "#{height}in",
      header_height: Keyword.get(opts, :header_height, "0"),
      header_font_size: Keyword.get(opts, :header_font_size, "10pt"),
      footer_height: Keyword.get(opts, :footer_height, "0"),
      footer_font_size: Keyword.get(opts, :footer_font_size, "10pt"),
      header_zoom: Keyword.get(opts, :header_zoom, default_zoom()),
      footer_zoom: Keyword.get(opts, :footer_zoom, default_zoom()),
      webkit_print_color_adjust: Keyword.get(opts, :webkit_print_color_adjust, "exact"),
      text_rendering: Keyword.get(opts, :text_rendering, "auto")
    ]
  end

  defp default_zoom do
    if semver_compare(ChromeRunner.version(), [120]) in [:eq, :gt] do
      "1"
    else
      "0.75"
    end
  end

  # Fetches paper size from opts, translates from config or uses given {width, height} tuple.
  defp get_paper_size(manual) when tuple_size(manual) === 2, do: manual

  defp get_paper_size(name) when is_atom(name) do
    Map.get(@paper_sizes_in_inch, name, @default_paper_size)
  end

  defp get_paper_size(opts) when is_list(opts) do
    opts
    |> Keyword.get(:size, @default_paper_size)
    |> get_paper_size()
    |> maybe_rotate_paper(Keyword.get(opts, :landscape, false))
  end

  # Inverts the paper size if landscape orientation.
  defp maybe_rotate_paper(size, false) when tuple_size(size) === 2, do: size
  defp maybe_rotate_paper({w, h}, true), do: {h, w}

  defp squish(css) do
    css
    |> String.trim()
    |> String.replace(~r/[[:space:]]+/, " ")
    |> String.replace(~r/\n/, "")
  end
end
