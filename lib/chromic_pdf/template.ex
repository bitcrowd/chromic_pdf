defmodule ChromicPDF.Template do
  @moduledoc """
  This module contains helper functions that make it easier to to build HTML templates (body,
  header, and footer) that fully cover a given page. Like an adapter, it tries to harmonize
  Chrome's `printToPDF` options and related CSS layout styles (`@page` and friends) with a custom
  set of page sizing options. Using this module is entirely optional, but perhaps can help to
  avoid some common pitfalls arising from the slightly unintuitive and sometimes conflicting
  behaviour of `printToPDF` options and `@page` CSS styles in Chrome.
  """

  require EEx

  @type blob :: binary()

  @type content_option ::
          {:content, blob()}
          | {:header, blob()}
          | {:footer, blob()}

  @type style_option ::
          {:width, binary()}
          | {:height, binary()}
          | {:header_height, binary()}
          | {:header_font_size, binary()}
          | {:footer_height, binary()}
          | {:footer_font_size, binary()}

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
        footer: "<p>footer</p>"
        width: "210mm",
        height: "297mm",
        header_height: "45mm",
        header_font_size: "20pt",
        footer_height: "40mm"
      )

  Content, header, and footer templates should be unwrapped HTML markup (i.e. no `<html>` around
  the content), prefixed with any `<style>` tags that your page needs.

      ChromicPDF.Template.source_and_options(
        content: \"""
        <style>
          h1 { font-size: 22pt; }
        </style>
        <h1>Hello</h1>
        \"""
      )
  """
  @spec source_and_options([content_option() | style_option()]) ::
          ChromicPDF.Processor.source_and_options()
  def source_and_options(opts) do
    content = Keyword.get(opts, :content, @default_content)
    header = Keyword.get(opts, :header, "")
    footer = Keyword.get(opts, :footer, "")
    styles = styles(opts)

    %{
      source: {:html, html_concat(styles, content)},
      opts: [
        print_to_pdf: %{
          preferCSSPageSize: true,
          displayHeaderFooter: true,
          headerTemplate: html_concat(styles, header),
          footerTemplate: html_concat(styles, footer)
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
    @page {
      width: <%= @width %>;
      height: <%= @height %>;
      margin: <%= @header_height %> 0 <%= @footer_height %>;
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

    body {
      margin: 0;
      padding: 0;
    }
  </style>
  """

  @doc """
  Renders page styles for given options.

  These base styles will configure page dimensions and header and footer heights. They also
  remove any browser padding and margins from these elements, and set the font-size.

  If you want to use these, make sure to set the `preferCSSPageSize: true` option, or use
  `source_and_options/1`.

  ## Options

  * `width` page width in any CSS unit, default: 279.4mm / 11 inches (US letter)
  * `height` default: 215.9mm / 8.5 inches
  * `header_height` default: zero
  * `header_font_size` default: 10pt
  * `footer_height` default: zero
  * `footer_font_size` default: 10pt
  """
  @spec styles([style_option()]) :: blob()
  def styles(opts \\ []) do
    assigns = [
      height: Keyword.get(opts, :height, "215.9mm"),
      width: Keyword.get(opts, :width, "279.4mm"),
      header_height: Keyword.get(opts, :header_height, "0"),
      header_font_size: Keyword.get(opts, :header_font_size, "10pt"),
      footer_height: Keyword.get(opts, :footer_height, "0"),
      footer_font_size: Keyword.get(opts, :footer_font_size, "10pt")
    ]

    render_styles(assigns)
  end

  EEx.function_from_string(:defp, :render_styles, @styles, [:assigns])
end
