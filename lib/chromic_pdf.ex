defmodule ChromicPDF do
  @moduledoc """
  ChromicPDF is a fast HTML2PDF renderer based on Chrome.

  ## Usage

  ### Boot

  Start ChromicPDF as part of your supervision tree:

      def MyApp.Application do
        def start(_type, _args) do
          children = [
            # other apps...
            {ChromicPDF, chromic_pdf_opts()}
          ]

          Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
        end

        defp chromic_pdf_opts do
          []
        end
      end

  ### Options

  ChromicPDF spawns two worker pools, the session pool and the ghostscript pool.  By default, it
  will create 5 workers with no overflow. To change these options, you may pass configuration to
  the supervisor.

  Please see https://github.com/devinus/poolboy for available options.

      defp chromic_pdf_opts do
        [
          session_pool: [
            size: 3,
            max_overflow: 0
          ],
          ghostscript_pool: [
            size: 10,
            max_overflow: 2
          ]
        ]
      end

  ### Print a PDF / PDF/A

  Please see `ChromicPDF.print_to_pdf/3` and `ChromicPDF.print_to_pdfa/3`.

  ## How it works

  ### PDF Printing

  * ChromicPDF spawns an instance of Chromium/Chrome (an OS process) and connects to its
    "DevTools" channel via file descriptors.
  * The Chrome process is supervised and the connected processes will automatically recover if it
    crashes.
  * A number of "targets" in Chrome are spawned, 1 per worker process in the `SessionPool`.
  * When a PDF print is requested, a session will instruct its assigned "target" to navigate to
    the given URL, then wait until it receives a "frameStoppedLoading" event, and proceed to call
    the `printToPDF` function.
  * The printed PDF will be sent to the session as Base64 encoded chunks.
  """

  use ChromicPDF.Supervisor

  def test do
    ChromicPDF.print_to_pdfa(
      "file:///Users/malte/work/maltoe/chromic_pdf/test.html",
      %{
        marginTop: 0.393701,
        marginLeft: 0.787402,
        marginRight: 0.787402,
        marginBottom: 1.1811,
        displayHeaderFooter: true,
        headerTemplate: "<span></span>",
        footerTemplate: """
        <style>
          p {
            color: #333;
            font-size: 10pt;
            text-align: right;
            margin-left: 0.787402in;
            margin-right: 0.787402in;
            width: 100%;
          }
        </style>
        <p>
        Page <span class="pageNumber"></span> of <span class="totalPages"></span>
        </p>
        """
      },
      "test.pdf"
    )
  end
end
