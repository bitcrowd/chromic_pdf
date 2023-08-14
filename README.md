![](assets/logo.svg)

[![CircleCI](https://circleci.com/gh/bitcrowd/chromic_pdf.svg?style=shield)](https://circleci.com/gh/bitcrowd/chromic_pdf)
[![Module Version](https://img.shields.io/hexpm/v/chromic_pdf.svg)](https://hex.pm/packages/chromic_pdf)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/chromic_pdf/)
[![Total Download](https://img.shields.io/hexpm/dt/chromic_pdf.svg)](https://hex.pm/packages/chromic_pdf)
[![License](https://img.shields.io/hexpm/l/chromic_pdf.svg)](https://github.com/bitcrowd/chromic_pdf/blob/master/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/bitcrowd/chromic_pdf.svg)](https://github.com/bitcrowd/chromic_pdf/commits/master)

ChromicPDF is a HTML-to-PDF renderer for Elixir, based on headless Chrome.

## Features

* **Node-free**: In contrast to [many other](https://hex.pm/packages?search=pdf&sort=recent_downloads) packages, it does not use [puppeteer](https://github.com/puppeteer/puppeteer), and hence does not require Node.js. It communicates directly with Chrome's [DevTools API](https://chromedevtools.github.io/devtools-protocol/) over pipes, offering the same performance as puppeteer, if not better.
* **Header/Footer**: Using the DevTools API allows to apply the full set of options of the [`printToPDF`](https://chromedevtools.github.io/devtools-protocol/tot/Page#method-printToPDF) function. Most notably, it supports header and footer HTML templates.
* **PDF/A**: It can convert printed files to PDF/A using Ghostscript. Converted files pass the [verapdf](https://verapdf.org/) validator.

## Requirements

- Chromium or Chrome
- Ghostscript (optional, for PDF/A support and concatenation of multiple sources)

ChromicPDF is tested in the following configurations:

| Elixir | Erlang/OTP | Distribution    | Chromium        | Ghostscript |
| ------ | ---------- | --------------- | --------------- | ----------- |
| 1.14.5 | 25.3.1     | Alpine 3.17     | 112.0.5615.165  | 10.01.1     |
| 1.14.0 | 25.1       | Alpine 3.16     | 102.0.5005.182  | 9.56.1      |
| 1.15.4 | 26.0.2     | Debian Bookworm | 115.0.5790.170  | 10.00.0     |
| 1.14.0 | 25.1       | Debian Bullseye | 108.0.5359.94   | 9.53.3      |
| 1.14.0 | 25.1       | Debian Buster   | 90.0.4430.212-1 | 9.27        |
| 1.11.4 | 22.3.4.26  | Debian Buster   | 90.0.4430.212-1 | 9.27        |

## Installation

ChromicPDF is a supervision tree (rather than an application). You will need to inject it into the supervision tree of your application. First, add ChromicPDF to your runtime dependencies:

```elixir
def deps do
  [
    {:chromic_pdf, "~> 1.12"}
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

### Main API

Here's how you generate a PDF from an external URL and store it in the local filesystem.

```elixir
# Prints a local HTML file to PDF.
ChromicPDF.print_to_pdf({:url, "https://example.net"}, output: "example.pdf")
```

The next example shows how to print a local HTML file to PDF/A, as well as the use of a callback
function that receives the generated PDF as path to a temporary file.

```elixir
ChromicPDF.print_to_pdfa({:url, "file:///example.html"}, output: fn pdf ->
  # Send pdf via mail, upload to S3, ...
end)
```

### Template API

[ChromicPDF.Template](https://hexdocs.pm/chromic_pdf/ChromicPDF.Template.html) contains
additional functionality that makes styling of PDF documents easier and overall provides a more
convenient API. See the documentation for details.

```elixir
[content: "<p>Hello Template</p>"]
|> ChromicPDF.Template.source_and_options()
|> ChromicPDF.print_to_pdf()
```

### Multiple sources

Multiple sources can be automatically concatenated using Ghostscript.

```elixir
ChromicPDF.print_to_pdf([{:html, "page 1"}, {:html, "page 2"}], output: "joined.pdf")
```

### Examples

* For a more complete example of how to integrate ChromicPDF in a Phoenix application, see [examples/phoenix](https://github.com/bitcrowd/chromic_pdf/tree/main/examples/phoenix).

## Development

This should get you started:

```
mix deps.get
mix test
```

For running the full suite of integration tests, please install and have in your `$PATH`:

* [`verapdf`](https://verapdf.org/)
* For `pdfinfo` and `pdftotext`, you need `poppler-utils` (most Linux distributions) or [Xpdf](https://www.xpdfreader.com/) (OSX)
* For the odd ZUGFeRD test in [`zugferd_test.exs`](https://github.com/bitcrowd/chromic_pdf/tree/main/test/integration/zugferd_test.exs), you need to download [ZUV](https://github.com/ZUGFeRD/ZUV) and set the `$ZUV_JAR` environment variable.

## Acknowledgements

* The PDF/A conversion is inspired by the `pdf2archive` script originally created by [@matteosecli](https://github.com/matteosecli/pdf2archive) and later enhanced by [@JaimeChavarriaga](https://github.com/JaimeChavarriaga/pdf2archive/tree/feature/support_pdf2b).

## Copyright and License

Copyright (c) 2019–2023 Bitcrowd GmbH

Licensed under the Apache License 2.0. See [LICENSE](LICENSE) file for details.
