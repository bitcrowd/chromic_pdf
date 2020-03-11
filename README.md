# ChromicPDF

[![Hex pm](http://img.shields.io/hexpm/v/chromic_pdf.svg?style=flat)](https://hex.pm/packages/chromic_pdf)
[![Hex docs](http://img.shields.io/badge/hex.pm-docs-green.svg?style=flat)](https://hexdocs.pm/chromic_pdf/ChromicPDF.html)
[![License](https://img.shields.io/hexpm/l/chromic_pdf?style=flat)](https://www.apache.org/licenses/LICENSE-2.0)
[![CircleCI](https://circleci.com/gh/bitcrowd/chromic_pdf.svg?style=shield)](https://circleci.com/gh/bitcrowd/chromic_pdf)

ChromicPDF is a small wrapper around Chrome's `printToPDF` API that allows to print a URL to PDF.

## Features

* **Node-free**: In contrast to [many other](https://hex.pm/packages?search=pdf&sort=recent_downloads) packages, it does not use [puppeteer](https://github.com/puppeteer/puppeteer), and hence does not require Node.js. It communicates directly with Chrome's [DevTools API](https://chromedevtools.github.io/devtools-protocol/) over pipes, offering the same performance as puppeteer, if not better.
* **Header/Footer**: Using the DevTools API allows to apply the full set of options of the [`printToPDF`](https://chromedevtools.github.io/devtools-protocol/tot/Page#method-printToPDF) function. Most notably, it supports header and footer HTML templates.
* **PDF/A**: It can convert printed files to PDF/A using Ghostscript, inspired by the `pdf2archive` script originally created by [@matteosecli](https://github.com/matteosecli/pdf2archive) and later enhanced by [@JaimeChavarriaga](https://github.com/JaimeChavarriaga/pdf2archive/tree/feature/support_pdf2b). Created PDF/A-2b and PDF/A-3b files pass the [verapdf](https://verapdf.org/) compliance checks.

## Requirements

* Chromium or Chrome
* Ghostscript (for PDF/A support)

## Installation

ChromicPDF is a supervision tree (rather than an application). You will need to inject it into the supervision tree of your application. First, add ChromicPDF to your runtime dependencies:

```elixir
def deps do
  [
    {:chromic_pdf, "~> 0.2.0"}
  ]
end
```

Next, start ChromicPDF as part of your application:

```elixir
# lib/my_app/application.ex
def MyApp.Application do
  def start(_type, _args) do
    children = [
      # other apps...
      ChromicPDF
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end
end
```

## Usage

### Example

```elixir
ChromicPDF.print_to_pdfa(
  # URL to of local file to print
  {:url, "file:///example.html"},

  # Parameters to the PDF renderer, specifically for Chromium's printToPDF function,
  # see https://chromedevtools.github.io/devtools-protocol/tot/Page#method-printToPDF
  print_to_pdf: %{
    # Margins are in given inches
    marginTop: 0.393701,
    marginLeft: 0.787402,
    marginRight: 0.787402,
    marginBottom: 1.1811,

    # Print header and footer (on each page).
    # This will print the default templates if none are given.
    displayHeaderFooter: true,

    # Even on empty string.
    # To disable header or footer, pass an empty element.
    headerTemplate: "<span></span>",

    # Example footer template.
    # They are completely unstyled by default and have a font-size of zero,
    # so don't despair if they don't show up at first.
    # There's a lot of documentation online about how to style them properly,
    # this is just a basic example. The <span> classes shown below are
    # interpolated by Chrome, see the printToPDF documentation.
    footerTemplate: """
    <style>
      p {
        color: #333;
        font-size: 10pt;
        text-align: right;
        margin: 0 0.787402in;
        width: 100%;
        z-index: 1000;
      }
    </style>
    <p>
    Page <span class="pageNumber"></span> of <span class="totalPages"></span>
    </p>
    """
  },

  # Parameters for the PDF/A converter
  info: %{
    title: "Example",
    author: "Jane Doe",
    creator: "ChromicPDF"
  },
  pdfa_version: "3",

  # Output path.
  output: "test.pdf"
)
```

## Development

For running the full suite of integration tests, please install and have in your `$PATH`:

* [`verapdf`](https://verapdf.org/)
* For `pdfinfo` and `pdftotext`, you need `poppler-utils` (most Linux distributions) or [Xpdf](https://www.xpdfreader.com/) (OSX)
* For the odd ZUGFeRD test in [`pdfa_generation_test.exs`](test/integration/pdfa_generation_test.exs), you need to download [ZUV](https://github.com/ZUGFeRD/ZUV) and set the `$ZUV_JAR` environment variable.
