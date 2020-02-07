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
      Prints a PDF and converts it to PDF/A-2b.
      """
      @spec print_to_pdfa(
              url :: binary(),
              params :: map(),
              output :: binary() | (binary() -> any())
            ) :: :ok
      def print_to_pdfa(url, params, output) do
        Processor.print_to_pdfa(__MODULE__, url, params, output)
      end
    end
  end
end
