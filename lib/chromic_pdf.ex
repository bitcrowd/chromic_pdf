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

  ## Options

  ### Worker pools

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

  ### Automatic session restarts to avoid memory drain

  By default, ChromicPDF will restart sessions within the Chrome process after 1000 operations.
  This helps to prevent infinite growth in Chrome's overall memory consumption. This "max age" of
  a session can be configured by setting the `:max_session_uses` option.

      defp chromic_pdf_opts do
        [max_session_uses: 1000]
      end

  ## Security Considerations

  Before adding a browser to your application's (perhaps already long) list of dependencies, you
  may want consider the security hints below.

  ### Escape user-supplied data

  If you can, make sure to escape any data provided by users with something like
  [`Phoenix.HTML.html_escape`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.html#html_escape/1).
  Chrome is designed to make displaying HTML pages relatively safe, in terms of preventing
  undesired access of a page to the host operating system. However, the attack surface of your
  application is still increased. Running this in a contained application with a small HTTP
  interface creates an additional barrier (and has other benefits).

  ### Running in online mode

  Browser targets will be spawned in "offline mode" by default (using the DevTools command
  [`Network.emulateNetworkConditions`](https://chromedevtools.github.io/devtools-protocol/tot/Network#method-emulateNetworkConditions).
  Users are required to take this extra step (basically reading this paragraph) to re-consider
  whether remote printing is a requirement.

  However, there are a lot of valid use-cases for printing from a URL, particularly from a
  webserver on localhost. To switch to "online mode", pass the `offline: false` parameter.

      def chromic_pdf_opts do
        [offline: false]
      end

  ### Chrome Sandbox

  By default, ChromicPDF will run Chrome targets in a sandboxed OS process. If you absolutely
  must run Chrome as root, you can turn of its sandbox by passing the `no_sandbox: true` option.

      defp chromic_pdf_opts do
        [no_sandbox: true]
      end

  ### Enabling Chrome stderr output

  Chrome's stderr logging is silently discarded to not obscure your logfiles. In case you would
  like to take a peek, add the `discard_stderr: false` option.

      defp chromic_pdf_opts do
        [discard_stderr: false]
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

  ### PDF/A Conversion

  * To convert a PDF to a PDF/A-3, ChromicPDF uses the [ghostscript](https://ghostscript.com/)
    utility.
  * Since it is required to embed a color scheme into PDF/A files, ChromicPDF ships with a copy
    of the free [`eciRGB_V2`](http://www.eci.org/) scheme by the European Color Initiative.
    If you need to be able a different color scheme, please open an issue.
  """

  use ChromicPDF.Supervisor
end
