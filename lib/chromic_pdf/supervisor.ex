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

      ## Example 1: Print to file

          ChromicPDF.print_to_pdf({:url, "file:///example.html"}, "output.pdf")

      ## Example 2: Print to temporary file

          ChromicPDF.print_to_pdf({:url, "file:///example.html"}, fn output_pdf ->
            send_download(...)
          end)

      The temporary file passed to the callback will be deleted when the callback returns.

      ## Example 3: Print with 2cm margin on each side

          ChromicPDF.print_to_pdf(
            {:url, "file:///example.html"},
            [print_to_pdf: %{
              marginTop: 0.787402,
              marginLeft: 0.787402,
              marginRight: 0.787402,
              marginBottom: 0.787402,
            }],
            "output.pdf"
          )

      ## Example 4: Print from in-memory HTML

      For convenience, it is also possible to pass a HTML blob to `print_to_pdf/3` which is
      automatically stored in a temporary file and cleaned up afterwards. It is served over
      the `file://` scheme.

          ChromicPDF.print_to_pdf(
            {:html, "<html><body><h1>Hello World!</h1></body></html>"},
            "output.pdf"
          )

      ## Options

      For a full list of options to the `printToPDF` function, please see the Chrome
      documentation at:

      https://chromedevtools.github.io/devtools-protocol/tot/Page#method-printToPDF
      """
      @spec print_to_pdf(
              url :: Processor.pdf_input(),
              pdf_params :: Processor.pdf_params(),
              output :: Processor.output()
            ) :: :ok
      def print_to_pdf(input, pdf_params \\ [], output) do
        input
        |> Processor.print_to_pdf(pdf_params, output)
        |> Processor.run(__MODULE__)
      end

      @doc """
      Converts a PDF to PDF/A (either PDF/A-2b or PDF/A-3b).

      ## Example

          ChromicPDF.convert_to_pdfa(
            "some_pdf_file.pdf",
            [info: %{creator: "ChromicPDF"}],
            "output.pdf"
          )

      ## PDF/A versions & levels

      Ghostscript supports both PDF/A-2 and PDF/A-3 versions, both in their `b` (basic) level. By
      default, ChromicPDF generates version PDF/A-3b files.  Set the `pdfa_version` option for
      version 2.

          ChromicPDF.convert_to_pdfa(
            "some_pdf_file.pdf",
            [pdfa_version: "2"],
            "output.pdf"
          )

      ## Specifying PDF metadata

      The converter is able to transfer PDF metadata (the `Info` dictionary) from the original
      PDF file to the output file. However, files printed by Chrome do not contain any metadata
      information (except "Creator" being "Chrome").

      The `:info` option of the PDF/A converter allows to specify metatadata for the output file
      directly. The converter understands the following keys, all of which accept only String
      values.

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
            [pdfa_def_ext: "[/Title (OverriddenTitle) /DOCINFO pdfmark"],
            "output.pdf"
          )
      """
      @spec convert_to_pdfa(
              pdf_path :: Processor.path(),
              pdfa_params :: Processor.pdfa_params(),
              output :: Processor.output()
            ) :: :ok
      def convert_to_pdfa(pdf_path, pdfa_params \\ [], output) do
        {:path, pdf_path}
        |> Processor.convert_to_pdfa(pdfa_params, output)
        |> Processor.run(__MODULE__)
      end

      @doc """
      Prints a PDF and converts it to PDF/A in a single call.

      See `print_to_pdf/3` and `convert_to_pdfa/3` for options.

      ## Example

          ChromicPDF.print_to_pdfa({:url, "https://example.net"}, [], [], "output.pdf")
      """
      @spec print_to_pdfa(
              url :: Processor.pdf_input(),
              pdf_params :: Processor.pdf_params(),
              pdfa_params :: Processor.pdfa_params(),
              output :: Processor.output()
            ) :: :ok
      def print_to_pdfa(input, pdf_params \\ [], pdfa_params \\ [], output) do
        input
        |> Processor.print_to_pdfa(pdf_params, pdfa_params, output)
        |> Processor.run(__MODULE__)
      end
    end
  end
end
