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

          ChromicPDF.print_to_pdf("https://example.net", "output.pdf")

      ## Example 2: Print to temporary file

          ChromicPDF.print_to_pdf("https://example.net", fn output_pdf ->
            send_download(...)
          end)

      The temporary file passed to the callback will be deleted when the callback returns.

      ## Example 3: Print with 2cm margin on each side

          ChromicPDF.print_to_pdf(
            "https://example.net",
            %{
              marginTop: 0.787402,
              marginLeft: 0.787402,
              marginRight: 0.787402,
              marginBottom: 0.787402,
            }
            "output.pdf"
          )


      ## Options

      For a full list of options to the `printToPDF` function, please see the Chrome
      documentation at:

      https://chromedevtools.github.io/devtools-protocol/tot/Page#method-printToPDF
      """
      @spec print_to_pdf(
              url :: binary(),
              params :: map(),
              output :: binary() | (binary() -> any())
            ) :: :ok
      def print_to_pdf(url, params \\ %{}, output) do
        Processor.print_to_pdf(__MODULE__, url, params, output)
      end

      @doc """
      Converts a PDF to PDF/A-2b.

      ## Example

          ChromicPDF.convert_to_pdfa(
            "some_pdf_file.pdf",
            [info: %{creator: "ChromicPDF"}],
            "output.pdf"
          )

      ## Specifying PDF metadata

      The converter is able to transfer PDF metadata (the `Info` dictionary) from the original PDF
      file to the output file. However, files printed by Chrome do not contain any metadata
      information (except "Creator" being "Chrome").

      The `:info` option of the PDF/A converter allows to specify metatadata for the output file
      directly. The converter understands the following keys, all of which accept only String values.

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
      """
      @spec convert_to_pdfa(
              pdf_file :: binary(),
              pdfa_params :: keyword(),
              output :: binary() | (binary() -> any())
            ) :: :ok
      def convert_to_pdfa(pdf_file, pdfa_params, output) do
        Processor.convert_to_pdfa(__MODULE__, pdf_file, pdfa_params, output)
      end

      @doc """
      Prints a PDF and converts it to PDF/A-2b in a single call.

      See `print_to_pdf/3` and `convert_to_pdfa/3` for options.
      """
      @spec print_to_pdfa(
              url :: binary(),
              pdf_params :: map(),
              pdfa_params :: keyword(),
              output :: binary() | (binary() -> any())
            ) :: :ok
      def print_to_pdfa(url, pdf_params, pdfa_params, output) do
        Processor.print_to_pdfa(__MODULE__, url, pdf_params, pdfa_params, output)
      end
    end
  end
end
