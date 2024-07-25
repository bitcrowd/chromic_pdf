# SPDX-License-Identifier: Apache-2.0

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

  ### Print a PDF

      ChromicPDF.print_to_pdf({:file, "example.html"}, output: "output.pdf")

  This tells Chrome to open the `example.html` file from your current directory and save the
  rendered page as `output.pdf`. PDF printing comes with a ton of options. Please see
  `ChromicPDF.print_to_pdf/2` for details.

  ### Print a PDF/A

      ChromicPDF.print_to_pdfa({:file, "example.html"}, output: "output.pdf")

  This prints the same PDF with Chrome and afterwards passes it to Ghostscript to convert it to a
  PDF/A. Please see `ChromicPDF.print_to_pdfa/2` or `ChromicPDF.convert_to_pdfa/2` for details.

  ## Security considerations

  By default, ChromicPDF will allow Chrome to make use of its own ["sandbox" process jail](https://chromium.googlesource.com/chromium/src/+/master/docs/design/sandbox.md).
  The sandbox tries to limit system resource access of the renderer processes to the minimum
  resources they require to perform their task. It is designed to make displaying HTML pages
  relatively safe, in terms of preventing undesired access of a page to the host operating system.

  Nevertheless, running a browser as part of your application, especially when used to process
  user-supplied content, significantly increases your attack surface. Hence, before adding
  ChromicPDF to your application's (perhaps already long) list of dependencies, you may want
  to consider the security hints below.

  ### Architectural isolation

  A great, if not the best option to mitigate security risks due to the use of ChromicPDF / a
  Browser in your stack, is to turn your "document renderer" component into a containerized
  service with a small RPC interface. This will create a nice barrier between Chrome and the rest
  of your application, so that even if an attacker manages to escape Chrome's sandbox, they will
  still be jailed within the container. It also has other benefits like better control of
  resources, e.g. how much CPU you want to dedicate to PDF rendering.

  ### Escape user-supplied data

  Make sure to always escape user-provided data with something like [`Phoenix.HTML.html_escape`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.html#html_escape/1).
  This should prevent an attacker from injecting malicious scripts into your template.

  ### Disabling scripts

  If your template allows, you can disable JavaScript execution altogether (using the
  DevTools command [`Emulation.setScriptExecutionDisabled`](https://chromedevtools.github.io/devtools-protocol/tot/Emulation/#method-setScriptExecutionDisabled))
  with the `:disable_scripts` option:

      def chromic_pdf_opts do
        [disable_scripts: true]
      end

  Note that this doesn't prevent other features like the `evaluate` option from working, it
  solely applies to scripts being supplied by the rendered page itself.

  ### Running in offline mode

  To prevent your templates from accessing any remote hosts, the browser targets can be spawned
  in "offline mode" (using the DevTools command [`Network.emulateNetworkConditions`](https://chromedevtools.github.io/devtools-protocol/tot/Network#method-emulateNetworkConditions)).
  Chrome targets with network conditions set to `offline` can't resolve any external URLs (e.g.
  `https://`), neither entered as navigation URL nor contained within the HTML body.

      def chromic_pdf_opts do
        [offline: true]
      end

  ### Chrome Sandbox in Docker containers

  In Docker containers running Linux images (e.g. images based on Alpine), and which
  are configured to run their main job as a non-root user, the sandbox may cause Chrome to crash
  on startup as it requires root privileges.

  The error output (`discard_stderr: false` option) looks as follows:

      Failed to move to new namespace: PID namespaces supported, Network namespace supported,
      but failed: errno = Operation not permitted

  The best way to resolve this issue is to configure your Docker container to use seccomp rules
  that grant Chrome access to the relevant system calls. See the excellent [Zenika/alpine-chrome](https://github.com/Zenika/alpine-chrome#-the-best-with-seccomp) repository for details on how to make this work.

  Alternatively, you may choose to disable Chrome's sandbox with the `no_sandbox` option.

      defp chromic_pdf_opts do
        [no_sandbox: true]
      end

  > #### Only local Chrome instances {: .neutral}
  >
  > This option is available only for local Chrome instances.

  ### SSL connections

  In you are fetching your print source from a `https://` URL, as usual Chrome verifies the
  remote host's SSL certificate when establishing the secure connection, and errors out of
  navigation if the certificate has expired or is not signed by a known certificate authority
  (i.e. no self-signed certificates).

  For production systems, this security check is essential and should not be circumvented.
  However, if for some reason you need to bypass certificate verification in development or test,
  you can do this with the `:ignore_certificate_errors` option.

      defp chromic_pdf_opts do
        [ignore_certificate_errors: true]
      end

  ## Session pool

  ChromicPDF spawns a pool of targets (= tabs) inside the launched Chrome process. These are held
  in memory to reduce initialization time in the PDF print jobs.

  ### Operation timeouts

  By default, ChromicPDF allows the print process to take 5 seconds to finish. In case you are
  printing large PDFs and run into timeouts, these can be configured configured by passing the
  `timeout` option to the session pool.

      defp chromic_pdf_opts do
        [
          session_pool: [timeout: 10_000]   # in milliseconds
        ]
      end

  ### Concurrency

  ChromicPDF depends on the [NimblePool](https://hexdocs.pm/nimble_pool) library to manage the
  browser sessions in a pool. To increase or limit the number of concurrent sessions, you can
  pass pool configuration to the supervisor.

      defp chromic_pdf_opts do
        [
          session_pool: [size: 3]
        ]
      end

  NimblePool performs simple queueing of operations. The maximum time an operation is allowed to
  wait in the queue is configurable with the `:checkout_timeout` option, and defaults to 5 seconds.

      defp chromic_pdf_opts do
        [
          session_pool: [checkout_timeout: 5_000]
        ]
      end

  Please note that this is not a persistent queue. If your concurrent demand exceeds the configured
  concurrency, your jobs will begin to time out. In this case, an asynchronous approach backed by a
  persistent job processor like Oban will give you better results, and likely improve your
  application's UX.

  ### Automatic session restarts to avoid memory drain

  By default, ChromicPDF will restart sessions within the Chrome process after 1000 operations.
  This helps to prevent infinite growth in Chrome's memory consumption. The "max age" of a session
  can be configured with the `:max_uses` option.

      defp chromic_pdf_opts do
        [
          session_pool: [max_uses: 1000]
        ]
      end

  ### Multiple session pools

  ChromicPDF supports running multiple named session pools to allow varying session configuration.
  For example, this makes it possible to have one pool that is not allowed to execute JavaScript while
  others can use JavaScript.

      defp chromic_pdf_opts do
        [
          session_pool: %{
            with_scripts: [],
            without_scripts: [disabled_scripts: true]
          }
        ]
      end

  When you define multiple session pools, you need to assign the pool to use in each PDF job:

      ChromicPDF.print_to_pdf(..., session_pool: :without_scripts)

  Global options are used as defaults for each configured pool. See
  `t:ChromicPDF.session_option/0` for a list of options for the session pools.

  ## Chrome zombies

  > Help, a Chrome army tries to take over my system!

  ChromicPDF tries its best to gracefully close the external Chrome process when its supervisor
  is terminated. Unfortunately, when the BEAM is not shutdown gracefully, Chrome processes will
  keep running.  While in a containerized production environment this is unlikely to be of
  concern, in development it can lead to unpleasant performance degradation of your operation
  system.

  In particular, the BEAM is not shutdown properly…

  * when you exit your application or `iex` console with the Ctrl+C abort mechanism (see issue [#56](https://github.com/bitcrowd/chromic_pdf/issues/56)),
  * and when you run your tests. No, after an ExUnit run your application's supervisor is
    not terminated cleanly.

  There are a few ways to mitigate this issue.

  ### "On Demand" mode

  In case you habitually end your development server with Ctrl+C, you should consider enabling "On
  Demand" mode which disables the session pool, and instead starts and stops Chrome instances as
  needed. If multiple PDF operations are requested simultaneously, multiple Chrome processes will
  be launched (each with a pool size of 1, disregarding the pool configuration).

      defp chromic_pdf_opts do
        [on_demand: true]
      end

  To enable it only for development, you can load the option from the application environment.

      # config/config.exs
      config :my_app, ChromicPDF, on_demand: false

      # config/dev.exs
      config :my_app, ChromicPDF, on_demand: true

      # application.ex
      @chromic_pdf_opts Application.compile_env!(:my_app, ChromicPDF)
      defp chromic_pdf_opts do
        @chromic_pdf_opts ++ [... other opts ...]
      end

  ### Terminating your supervisor after your test suite

  You can enable "On Demand" mode for your tests, as well. However, please be aware that each
  test that prints a PDF will have an increased runtime (plus about 0.5s) due to the added Chrome
  boot time cost. Luckily, ExUnit provides a [method](https://hexdocs.pm/ex_unit/ExUnit.html#after_suite/1)
  to run code at the end of your test suite.

      # test/test_helper.exs
      ExUnit.after_suite(fn _ -> Supervisor.stop(MyApp.Supervisor) end)
      ExUnit.start()

  ### Only start ChromicPDF in production

  The easiest way to prevent Chrome from spawning in development is to only run ChromicPDF in
  the `prod` environment. However, obviously you won't be able to print PDFs in development or
  test then.

  ## Chrome options

  By default, ChromicPDF will try to run a Chrome instance in the local environment. The
  following options allow to customize the generated command line.

  ### Custom command line switches

  The `:chrome_args` option allows to pass arbitrary options to the Chrome/Chromium executable.

      defp chromic_pdf_opts do
        [chrome_args: "--font-render-hinting=none"]
      end

  In some cases, ChromicPDF's default arguments (e.g. `--disable-gpu`) may conflict with the ones
  you would like to add. In this case, use can supply a keyword list to the `:chrome_args` option
  which allows targeted removing of default arguments.

      defp chromic_pdf_opts do
        [chrome_args: [
          append: "--headless=new --angle=swiftshader",
          remove: ["--headless", "--disable-gpu"]
        ]]
      end

  The `:chrome_executable` option allows to specify a custom Chrome/Chromium executable.

      defp chromic_pdf_opts do
        [chrome_executable: "/usr/bin/google-chrome-beta"]
      end

  ### Font rendering issues on Linux

  On Linux, Chrome and its rendering engine Skia have longstanding issues with rendering certain fonts for print media, especially with regards to letter kerning. See [this issue](https://github.com/puppeteer/puppeteer/issues/2410) in puppeteer for a discussion. If your documents suffer from incorrectly spaced letters, you can try some of the following:

  - Apply the `text-rendering: geometricPrecision` CSS rule. In our tests, this has shown to be the most reliable option. Besides, it is also the most flexible option as you can apply it to individual elements depending on the font-face they use. Recommended.
  - Set `--font-render-hinting=none` or `--disable-font-subpixel-positioning` command line switches (see `:chrome_args` option above). While this generally improved text rendering in all our tests, it is a bit of a mallet method.

  See also [this blog post](https://www.browserless.io/blog/2020/09/30/puppeteer-print/) for more hints.

  ### Debugging Chrome errors

  Chrome's stderr logging is silently discarded to not obscure your logfiles. In case you would
  like to take a peek, add the `discard_stderr: false` option.

      defp chromic_pdf_opts do
        [discard_stderr: false]
      end

  ### Remote Chrome

  Instead of running a local Chrome instance, you may connect to an external Chrome instance via its websocket-based debugging interface. For example, you can run a headless Chrome inside a docker container using the minimalistic [Zenika/alpine-chrome](https://github.com/Zenika/alpine-chrome) images:

      $ docker run --rm -p 9222:9222       \\
        zenika/alpine-chrome:114           \\
        --no-sandbox                       \\
        --headless                         \\
        --remote-debugging-port=9222       \\
        --remote-debugging-address=0.0.0.0

  See the [`ChromicPDF.ChromeRunner`](https://github.com/bitcrowd/chromic_pdf/blob/main/lib/chromic_pdf/pdf/chrome_runner.ex) module for a list of command line arguments that may improve your headless Chrome experience.

  To enable remote connections to Chrome, you need to specify the hostname and port of the running Chrome instance using the `:chrome_address` option. Setting this option will disable the command line-related options discussed above.

      defp chromic_pdf_opts do
        [chrome_address: {"localhost", 9222}]
      end

  To communicate with Chrome through its the websocket interface, ChromicPDF has an optional dependency on the [websockex](https://github.com/Azolo/websockex/) package, which you need to explicitly add to your `mix.exs`:

      def deps do
        [
          {:chromic_pdf, "..."},
          {:websockex, "~> 0.4.3"}
        ]
      end

  In case you have added `websockex` after `chromic_pdf` had already been compiled, you need to force a recompilation with `mix deps.compile --force chromic_pdf`.

  > #### Experimental {: .warning}
  >
  > Please note that support for remote connections is considered experimental. Be aware that between restarts ChromicPDF may leave tabs behind and your external Chrome process may leak memory.

  ## Ghostscript pool

  In addition to the session pool, a pool of ghostscript "executors" is started, in order to limit
  this resource as well. By default, ChromicPDF allows the same number of concurrent Ghostscript
  processes to run as it spawns sessions in Chrome itself.

      defp chromic_pdf_opts do
        [
          ghostscript_pool: [size: 10]
        ]
      end

  ## Telemetry support

  To provide insights into PDF and PDF/A generation performance, ChromicPDF executes the
  following telemetry events:

  * `[:chromic_pdf, :print_to_pdf, :start | :stop | exception]`
  * `[:chromic_pdf, :capture_screenshot, :start | :stop | :exception]`
  * `[:chromic_pdf, :convert_to_pdfa, :start | :stop | exception]`

  Please see [`:telemetry.span/3`](https://hexdocs.pm/telemetry/telemetry.html#span-3) for
  details on their payloads, and [`:telemetry.attach/4`](https://hexdocs.pm/telemetry/telemetry.html#attach-4)
  for how to attach to them.

  Each of the corresponding functions accepts a `telemetry_metadata` option which is passed to
  the attached event handler. This can, for instance, be used to mark events with custom tags such
  as the type of the print document.

      ChromicPDF.print_to_pdf(..., telemetry_metadata: %{template: "invoice"})

  The `print_to_pdfa/2` function emits both the `print_to_pdf` and `convert_to_pdfa` event series,
  in that order.

  Last but not least, the `print_to_pdf/2` function emits `:join_pdfs` events when concatenating
  multiple input sources.

  * `[:chromic_pdf, :join_pdfs, :start | :stop | exception]`

  ## Further options

  ### Debugging JavaScript errors & warnings

  By default, unhandled runtime exceptions thrown in JavaScript execution contexts are logged.
  You may choose to instead convert them into an Elixir exception by passing the following option:

      defp chromic_pdf_opts do
        # :ignore | :log (default) | :raise
        [unhandled_runtime_exceptions: :raise]
      end

  Alternatively, you can pass `:ignore` to silence the log statement.

  Calls to `console.log` & friends are ignored by default, and can be configured to be logged
  like this:

      defp chromic_pdf_opts do
        # :ignore (default) | :log | :raise
        [console_api_calls: :log]
      end

  ## On Accessibility / PDF/UA

  Since its version 85, Chrome generates "Tagged PDF" files [by
  default](https://blog.chromium.org/2020/07/using-chrome-to-generate-more.html).  These files
  contain structural information about the document, i.e. type information about the nodes
  (headings, paragraph, etc.), as well as metadata like node attributes (e.g., image alt texts).
  This information allows assistive tools like screen readers to do their job, at the cost of
  (at times significantly) increasing the file size. To check whether a PDF file is tagged, you
  can use the `pdfinfo` utility, it reports these files as `Tagged: yes`. You can review some of
  the contained information with the `pdfinfo -struct-text <file>` command. Tagging may be
  disabled by passing the `--disable-pdf-tagging` argument to Chrome via the `chrome_args` option.

  However, at the time of writing, Chrome's most recent beta version 109 does not generate files
  compliant to the PDF/UA standard (ISO 14289-1:2014). Both the ["PAC 2021" accessibility
  checker](https://pdfua.foundation/en/pdf-accessibility-checker-pac/) and the VeraPDF validator
  (capable of validating a subset of the PDF/UA rules since [version 1.18 from April
  2021](https://www.pdfa.org/presentation/open-source-implementation-of-pdf-ua-validation/)) report
  rule violations concerning mandatory metadata.

  So, if your use-case requires you to generate fully PDF/UA-compliant files, at the moment Chrome
  (and by extension, ChromicPDF) is not going fulfill your needs.

  Furthermore, any operation that involves running the Chrome-generated file through Ghostscript
  (PDF/A conversion, concatenation) will **remove all structural information**, so that `pdfinfo`
  reports `Tagged: no`, and thereby prevent assistive tools from proper functioning.
  """

  use ChromicPDF.Supervisor

  @doc """
  Runs a one-off Chrome process to allow Chrome to initialize its caches.

  On some infrastructure (notably, Github Actions), Chrome occasionally takes a long nap between
  process launch and first replying to DevTools commands. If meanwhile you happen to print a PDF
  (so, before any sessions have been spawned by the session pool), the session checkout will fail
  with a timeout error:

      Caught EXIT signal from NimblePool.checkout!/4

            ** (EXIT) time out

  This function mitigates the issue by launching a Chrome process via a shell command, bypassing
  ChromicPDF's internals.

  ## Usage

      # in your test_helper.exs
      {:ok, _} = ChromicPDF.warm_up()
      ...
      ExUnit.start()

  ## Options

  This function accepts all options of `print_to_pdf/2` related to external Chrome process.

  If you pass `discard_stderr: false`, Chrome's standard error is returned.

      {:ok, stderr} = ChromicPDF.warm_up(discard_stderr: false)
      IO.inspect(stderr, label: "chrome stderr")

  ## Mix Task

  Alternatively, you can choose to run a mix task as part of your CI script, see
  `Mix.Tasks.ChromicPdf.WarmUp`. The task currently does not accept any options.

      ...
      $ mix chromic_pdf.warm_up
      $ mix test

  """
  @spec warm_up() :: {:ok, binary()}
  @spec warm_up([ChromicPDF.local_chrome_option()]) :: {:ok, binary()}
  def warm_up(opts \\ []) do
    ChromicPDF.ChromeRunner.warm_up(opts)
  end
end
