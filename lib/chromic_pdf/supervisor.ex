defmodule ChromicPDF.Supervisor do
  @moduledoc """
  Use this for multiple ChromicPDF instances.

  ## When is this useful?

  * You want to completely separate two or more PDF "queues"
  * You want to give your PDF module a custom API

  ## Usage

      defmodule MyApp.MyPDFGenerator do
        use ChromicPDF.Supervisor
      end

      def MyApp.Application do
        def start(_type, _args) do
          children = [
            MyApp.MyPDFGenerator
          ]

          Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
        end
      end
  """

  @doc false
  defmacro __using__(_opts) do
    # credo:disable-for-next-line Credo.Check.Refactor.LongQuoteBlocks
    quote do
      use Supervisor
      alias ChromicPDF.{Browser, GhostscriptPool, Processor, SessionPool}

      def start_link(config \\ []) do
        Supervisor.start_link(__MODULE__, config, name: __MODULE__)
      end

      @impl Supervisor
      def init(config) do
        config = Keyword.merge(config, chromic: __MODULE__)

        children = [
          {GhostscriptPool, config},
          {Browser, config},
          {SessionPool, config}
        ]

        Supervisor.init(children, strategy: :rest_for_one)
      end

      @doc """
      Prints a PDF.

      This call blocks until the PDF has been created.

      ## Print and return Base64-encoded PDF

          {:ok, blob} = ChromicPDF.print_to_pdf({:url, "file:///example.html"})

          # Can be displayed in iframes
          "data:application/pdf;base64,\#{blob}"

      ## Print to file

          ChromicPDF.print_to_pdf({:url, "file:///example.html"}, output: "output.pdf")

      ## Print to temporary file

          ChromicPDF.print_to_pdf({:url, "file:///example.html"}, output: fn path ->
            send_download(path)
          end)

      The temporary file passed to the callback will be deleted when the callback returns.

      ## PDF printing options

          ChromicPDF.print_to_pdf(
            {:url, "file:///example.html"},
            print_to_pdf: %{
              marginTop: 0.787402,
              marginLeft: 0.787402,
              marginRight: 0.787402,
              marginBottom: 0.787402,
            }
          )

      Please note the camel-case. For a full list of options to the `printToPDF` function,
      please see the Chrome documentation at:

      https://chromedevtools.github.io/devtools-protocol/tot/Page#method-printToPDF

      ## Print from in-memory HTML

      For convenience, it is also possible to pass a HTML blob to `print_to_pdf/2`. The HTML is
      sent to the target using the [`Pahe.setDocumentContent`](https://chromedevtools.github.io/devtools-protocol/tot/Page#method-setDocumentContent) function.

          ChromicPDF.print_to_pdf(
            {:html, "<html><body><h1>Hello World!</h1></body></html>"}
          )
      """
      @spec print_to_pdf(
              url :: Processor.source(),
              opts :: [Processor.pdf_option()]
            ) :: :ok | {:ok, Processor.blob()}
      def print_to_pdf(input, opts \\ []) do
        Processor.print_to_pdf(__MODULE__, input, opts)
      end

      @doc """
      Captures a screenshot.

      This call blocks until the screenshot has been created.

      ## Print and return Base64-encoded PNG

          {:ok, blob} = ChromicPDF.capture_screenshot({:url, "file:///example.html"})

      ## Options

      Options can be passed by passing a map to the `:capture_screenshot` key.

          ChromicPDF.capture_screenshot(
            {:url, "file:///example.html"},
            capture_screenshot: %{
              format: "jpeg"
            }
          )

      Please see docs for details:

      https://chromedevtools.github.io/devtools-protocol/tot/Page#method-captureScreenshot
      """
      @spec capture_screenshot(
              url :: Processor.source(),
              opts :: keyword()
            ) :: :ok | {:ok, Processor.blob()}
      def capture_screenshot(input, opts \\ []) do
        Processor.capture_screenshot(__MODULE__, input, opts)
      end

      @doc """
      Converts a PDF to PDF/A (either PDF/A-2b or PDF/A-3b).

      ## Convert an input PDF and return a Base64-encoded blob

          {:ok, blob} = ChromicPDF.convert_to_pdfa("some_pdf_file.pdf")

      ## Convert and write to file

          ChromicPDF.convert_to_pdfa("some_pdf_file.pdf", output: "output.pdf")

      ## PDF/A versions & levels

      Ghostscript supports both PDF/A-2 and PDF/A-3 versions, both in their `b` (basic) level. By
      default, ChromicPDF generates version PDF/A-3b files.  Set the `pdfa_version` option for
      version 2.

          ChromicPDF.convert_to_pdfa("some_pdf_file.pdf", pdfa_version: "2")

      ## Specifying PDF metadata

      The converter is able to transfer PDF metadata (the `Info` dictionary) from the original
      PDF file to the output file. However, files printed by Chrome do not contain any metadata
      information (except "Creator" being "Chrome").

      The `:info` option of the PDF/A converter allows to specify metatadata for the output file
      directly.

          ChromicPDF.convert_to_pdfa("some_pdf_file.pdf", info: %{creator: "ChromicPDF"})

      The converter understands the following keys, all of which accept only String values:

      * `:title`
      * `:author`
      * `:subject`
      * `:keywords`
      * `:creator`
      * `:creation_date`
      * `:mod_date`

      By specification, date values in `:creation_date` and `:mod_date` do not need to follow a
      specific syntax. However, Ghostscript inserts date strings like `"D:20200208153049+00'00'"`
      and Info extractor tools might rely on this or another specific format. The converter will
      automatically format given `DateTime` values like this.

      Both `:creation_date` and `:mod_date` are filled with the current date automatically (by
      Ghostscript), if the original file did not contain any.

      ## Adding more PostScript to the conversion

      The `pdfa_def_ext` option can be used to feed more PostScript code into the final conversion
      step. This can be useful to add additional features to the generated PDF-A file, for
      instance a ZUGFeRD invoice.

          ChromicPDF.convert_to_pdfa(
            "some_pdf_file.pdf",
            pdfa_def_ext: "[/Title (OverriddenTitle) /DOCINFO pdfmark",
          )
      """
      @spec convert_to_pdfa(
              pdf_path :: Processor.path(),
              opts :: [Processor.pdfa_option()]
            ) :: :ok | {:ok, Processor.blob()}
      def convert_to_pdfa(pdf_path, opts \\ []) do
        Processor.convert_to_pdfa(__MODULE__, pdf_path, opts)
      end

      @doc """
      Prints a PDF and converts it to PDF/A in a single call.

      See `print_to_pdf/2` and `convert_to_pdfa/2` for options.

      ## Example

          ChromicPDF.print_to_pdfa({:url, "https://example.net"})
      """
      @spec print_to_pdfa(
              url :: Processor.source(),
              opts :: [Processor.pdf_option() | Processor.pdfa_option()]
            ) :: :ok | {:ok, Processor.blob()}
      def print_to_pdfa(input, opts \\ []) do
        Processor.print_to_pdfa(__MODULE__, input, opts)
      end
    end
  end
end
