# ChromicPDF

ChromicPDF is a small wrapper around Chrome's `printToPDF` API that allows to print a URL to PDF.

## Features

* **Node-free**: In contrast to [many other](https://hex.pm/packages?search=pdf&sort=recent_downloads) packages, it does not use [puppeteer](https://github.com/puppeteer/puppeteer), and hence does not require Node.js. It communicates directly with Chrome's [DevTools API](https://chromedevtools.github.io/devtools-protocol/) over pipes, offering the same performance as puppeteer, if not better.
* **Header/Footer**: Using the DevTools API allows to apply the full set of options of the [`printToPDF`](https://chromedevtools.github.io/devtools-protocol/tot/Page#method-printToPDF) function. Most notably, it supports header and footer HTML templates.
* **PDF/A-2b & PDF/A-3b**: It has PDF/A (basic) support using Ghostscript, inspired by the `pdf2archive` script originally created by [@matteosecli](https://github.com/matteosecli/pdf2archive) and later enhanced by [@JaimeChavarriaga](https://github.com/JaimeChavarriaga/pdf2archive/tree/feature/support_pdf2b). Created PDF/A files pass the [verapdf](https://verapdf.org/) compliance checks.

## Requirements

* Chromium or Chrome
* Ghostscript (for PDF/A support)

## Installation

ChromicPDF is a supervision tree (rather than an application). You will need to inject it into the supervision tree of your application. First, add ChromicPDF to your runtime dependencies:

```elixir
def deps do
  [
    {:chromic_pdf, "~> 0.1.0"}
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
  # URL to print, you can also use the file:// scheme
  {:url, "https:///example.net/"},

  # Parameters to Chromium's printToPDF function,
  # see https://chromedevtools.github.io/devtools-protocol/tot/Page#method-printToPDF
  %{
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

  # PDF metadata
  [
    info: %{
      title: "Example",
      author: "Jane Doe",
      creator: "ChromicPDF"
    },
    pdfa_version: "3"
  ],

  # Output path.
  "test.pdf"
)
```

## Development

For running the full suite of integration tests, please install and have in your `$PATH`:

* [`verapdf`](https://verapdf.org/)
* For `pdfinfo` and `pdftotext`, you need `poppler-utils` (most Linux distributions) or [Xpdf](https://www.xpdfreader.com/) (OSX)
* For the odd ZUGFeRD test in [`pdfa_generation_test.exs`](test/integeration/pdfa_generation_test.exs), you need to download [ZUV](https://github.com/ZUGFeRD/ZUV) and set the `$ZUV_JAR` environment variable.
