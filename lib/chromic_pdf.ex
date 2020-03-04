defmodule ChromicPDF do
  @moduledoc """
  ChromicPDF is a fast HTML-to-PDF/A renderer based on Chrome & Ghostscript.

  ## Usage

  ### Start

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

  ### Print a PDF or PDF/A

      ChromicPDF.print_to_pdf({:url, "file:///example.html"}, output: "output.pdf")

  See `ChromicPDF.print_to_pdf/2` and `ChromicPDF.convert_to_pdfa/2`.

  ### Options

  ChromicPDF spawns two worker pools, the session pool and the ghostscript pool. By default, it
  will create 5 workers with no overflow. To change these options, you can pass configuration to
  the supervisor. Please note that these are only worker pools. If you intend to max them out,
  you will need a job queue as well.

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

  ## Security Considerations

  Before adding a browser to your application's (perhaps already long) list of dependencies, you
  may want consider the security hints below.

  ### Escape user-supplied data

  If you can, make sure to escape any data provided by users with something like
  [`Phoenix.HTML.escape_html`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.html#html_escape/1).
  Chrome is designed to make displaying HTML pages relatively safe, in terms of preventing
  undesired access of a page to the host operating system. However, the attack surface of your
  application is still increased. Running this in a contained application with a small HTTP
  interface creates an additional barrier (and has other benefits).

  ### Running in online mode

  Before navigating to a URL, browser targets will switch to "offline mode" by default, using the
  DevTools command [`Network.emulateNetworkConditions`](https://chromedevtools.github.io/devtools-protocol/tot/Network#method-emulateNetworkConditions).
  Users are required to take this extra step (basically reading this paragraph) to re-consider
  whether remote printing is a requirement.

  However, there are a lot of valid use-cases for printing from a URL, particularly from a
  webserver on localhost. To switch to "online mode", pass the `offline: false` parameter when
  printing.

      ChromicPDF.print_to_pdf(
        {:url, "http://localhost:4000/invoices/123"},
        offline: false,
        output: "output.pdf"
      )

  ### Chrome Sandbox

  By default, ChromicPDF will run Chrome targets in a sandboxed OS process. If you absolutely
  must run Chrome as root, you can turn of its sandbox by passing the `no_sandbox: true` option.

      defp chromic_pdf_opts do
        [no_sandbox: true]
      end

  ## How it works

  ### PDF Printing

  * ChromicPDF spawns an instance of Chromium/Chrome (an OS process) and connects to its
    "DevTools" channel via file descriptors.
  * The Chrome process is supervised and the connected processes will automatically recover if it
    crashes.
  * A number of "targets" in Chrome are spawned, 1 per worker process in the `SessionPool`. By
    default, ChromicPDF will spawn each session in a new browser context (i.e., a profile).
  * When a PDF print is requested, a session will instruct its assigned "target" to navigate to
    the given URL, then wait until it receives a "frameStoppedLoading" event, and proceed to call
    the `printToPDF` function.
  * The printed PDF will be sent to the session as Base64 encoded chunks.
  """

  use ChromicPDF.Supervisor
end
