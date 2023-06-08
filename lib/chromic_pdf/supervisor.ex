# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.Supervisor do
  @moduledoc """
  Use this for multiple ChromicPDF instances.

  ## When is this useful?

  * You want to completely separate two or more PDF worker pools
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

  import ChromicPDF.Utils, only: [find_supervisor_child: 2, find_supervisor_child!: 2]
  alias ChromicPDF.{Browser, GhostscriptPool}

  @type services :: %{
          browser: pid(),
          ghostscript_pool: pid()
        }

  @spec child_spec([ChromicPDF.global_option()]) :: Supervisor.child_spec()
  def child_spec(config) do
    %{
      id: Keyword.fetch!(config, :name),
      start: {__MODULE__, :start_link, [config]},
      type: :supervisor
    }
  end

  @doc false
  @spec start_link([ChromicPDF.global_option()]) :: Supervisor.on_start()
  def start_link(config) do
    name = Keyword.fetch!(config, :name)

    children = [
      if Keyword.get(config, :on_demand, false) do
        {Agent, fn -> config end}
      else
        {Browser, config}
      end,
      {GhostscriptPool, config}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: name)
  end

  @doc """
  Fetches pids of the supervisor's services and passes them to the given callback function.

  If ChromicPDF has been configured to run in `on_demand` mode, this will start a temporary
  browser instance.
  """
  @spec with_services(atom(), (services() -> any())) :: any()
  def with_services(name, fun) do
    supervisor =
      Process.whereis(name) ||
        raise("""
        Can't find a running ChromicPDF instance.

        Please make sure to start its supervisor as part of your application.

            def start(_type, _args) do
              children = [
                # other apps...
                #{__MODULE__ |> to_string() |> String.replace("Elixir.", "")}
              ]

              Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
            end
        """)

    with_browser(supervisor, fn browser ->
      fun.(%{
        browser: browser,
        ghostscript_pool: find_supervisor_child!(supervisor, GhostscriptPool)
      })
    end)
  end

  defp with_browser(supervisor, fun) do
    if browser = find_supervisor_child(supervisor, Browser) do
      fun.(browser)
    else
      with_on_demand_browser(supervisor, fun)
    end
  end

  defp with_on_demand_browser(supervisor, fun) do
    config =
      supervisor
      |> find_supervisor_child!(Agent)
      |> Agent.get(& &1)
      |> Keyword.update(:session_pool, [size: 1], &Keyword.put(&1, :size, 1))
      |> Keyword.delete(:on_demand)

    {:ok, browser} = Browser.start_link(config)

    try do
      fun.(browser)
    after
      Process.exit(browser, :normal)
    end
  end

  @doc false
  defmacro __using__(_opts) do
    # credo:disable-for-next-line Credo.Check.Refactor.LongQuoteBlocks
    quote do
      import ChromicPDF.Supervisor, only: [with_services: 2]
      alias ChromicPDF.API

      @type url :: binary()
      @type path :: binary()

      @type source_tuple :: {:url, url()} | {:html, iodata()}
      @type source_and_options :: %{source: source_tuple(), opts: [pdf_option()]}
      @type source :: source() | source_and_options()

      @type output_function_result :: any()
      @type output_function :: (binary() -> output_function_result())
      @type output_option :: {:output, binary()} | {:output, output_function()}

      @type telemetry_metadata_option :: {:telemetry_metadata, map()}

      @type export_option ::
              output_option()
              | telemetry_metadata_option()

      @type export_return :: :ok | {:ok, binary()} | {:ok, output_function_result()}

      @type info_option ::
              {:info,
               %{
                 optional(:title) => binary(),
                 optional(:author) => binary(),
                 optional(:subject) => binary(),
                 optional(:keywords) => binary(),
                 optional(:creator) => binary(),
                 optional(:creation_date) => binary() | DateTime.t(),
                 optional(:mod_date) => binary() | DateTime.t()
               }}

      @type evaluate_option :: {:evaluate, %{required(:expression) => binary()}}

      @type wait_for_option ::
              {:wait_for,
               %{
                 required(:selector) => binary(),
                 required(:attribute) => binary()
               }}

      @type navigate_option ::
              {:set_cookie, map()}
              | evaluate_option()
              | wait_for_option()

      @type pdf_option ::
              {:print_to_pdf, map()}
              | navigate_option()

      @type pdfa_option ::
              {:pdfa_version, binary()}
              | {:pdfa_def_ext, binary()}
              | {:permit_read, binary()}
              | info_option()

      @type capture_screenshot_option ::
              {:capture_screenshot, map()}
              | navigate_option()

      @type session_pool_option ::
              {:size, non_neg_integer()}
              | {:init_timeout, timeout()}
              | {:timeout, timeout()}

      @type ghostscript_pool_option :: {:size, non_neg_integer()}

      @type chrome_runner_option ::
              {:no_sandbox, boolean()}
              | {:discard_stderr, boolean()}
              | {:chrome_args, binary()}
              | {:chrome_executable, binary()}

      @type global_option ::
              {:name, atom()}
              | {:offline, boolean()}
              | {:disable_scripts, boolean()}
              | {:unhandled_runtime_exceptions, :ignore | :log | :raise}
              | {:max_session_uses, non_neg_integer()}
              | {:session_pool, [session_pool_option()]}
              | {:ignore_certificate_errors, boolean()}
              | {:ghostscript_pool, [ghostscript_pool_option()]}
              | {:on_demand, boolean()}
              | chrome_runner_option()

      @doc """
      Returns a specification to start this module as part of a supervision tree.
      """
      @spec child_spec([global_option()]) :: Supervisor.child_spec()
      def child_spec(config) do
        id = Keyword.get(config, :name, __MODULE__)

        %{
          id: id,
          start: {__MODULE__, :start_link, [config]},
          type: :supervisor
        }
      end

      @doc """
      Starts ChromicPDF.

      ## "On Demand" mode

      If the given config includes the `on_demand: true` flag, this will not spawn a Chrome
      instance but instead hold the configuration in an Agent until a PDF print job is triggered.
      The print job will launch a temporary browser process and perform a graceful shutdown at
      the end.

      Please note that the browser process is spawned from your client process and that these
      processes are linked. If your client process is trapping `EXIT` signals, you will receive
      a message when the browser is terminated.
      """
      @spec start_link() :: Supervisor.on_start()
      @spec start_link([global_option()]) :: Supervisor.on_start()
      def start_link(config \\ []) do
        config
        |> Keyword.put_new(:name, __MODULE__)
        |> ChromicPDF.Supervisor.start_link()
      end

      @doc ~S'''
      Prints a PDF.

      This call blocks until the PDF has been created.

      ## Output options

      ### Print and return Base64-encoded PDF

          {:ok, blob} = ChromicPDF.print_to_pdf({:url, "file:///example.html"})

          # Can be displayed in iframes
          "data:application/pdf;base64,\#{blob}"

      ### Print to file

          :ok = ChromicPDF.print_to_pdf({:url, "file:///example.html"}, output: "output.pdf")

      ### Print to temporary file

          {:ok, :some_result} =
            ChromicPDF.print_to_pdf({:url, "file:///example.html"}, output: fn path ->
              send_download(path)
              :some_result
            end)

      The temporary file passed to the callback will be deleted when the callback returns.

      ## Input options

      ChromicPDF offers two primary methods of supplying Chrome with the HTML source to print.
      You can choose between passing in an URL for Chrome to load and injecting the HTML markup
      directly into the DOM through the remote debugging API.

      ### Print from URL

      Passing in a URL is the simplest way of printing a PDF. A target in Chrome is told to
      navigate to the given URL. When navigation is finished, the PDF is printed.

          ChromicPDF.print_to_pdf({:url, "file:///example.html"})

          ChromicPDF.print_to_pdf({:url, "http://example.net"})

          ChromicPDF.print_to_pdf({:url, "https://example.net"})

      #### Cookies

      If your URL requires authentication, you can pass in a session cookie. The cookie is
      automatically cleared after the PDF has been printed.

          cookie = %{
            name: "foo",
            value: "bar",
            domain: "localhost"
          }

          ChromicPDF.print_to_pdf({:url, "http:///example.net"}, set_cookie: cookie)

      See [`Network.setCookie`](https://chromedevtools.github.io/devtools-protocol/tot/Network#method-setCookie)
      for options. `name` and `value` keys are required.

      ### Print from in-memory HTML

      Alternatively, `print_to_pdf/2` allows to pass an in-memory HTML blob to Chrome in a
      `{:html, blob()}` tuple. The HTML is sent to the target using the [`Page.setDocumentContent`](https://chromedevtools.github.io/devtools-protocol/tot/Page#method-setDocumentContent)
      function. Oftentimes this method is preferable over printing a URL if you intend to render
      PDFs from templates rendered within the application that also hosts ChromicPDF, without the
      need to route the content through an actual HTTP endpoint. Also, this way of passing the
      HTML source has slightly better performance than printing a URL.

          ChromicPDF.print_to_pdf(
            {:html, "<h1>Hello World!</h1>"}
          )

      #### In-memory content can be iodata

      In-memory HTML for both the main input parameter as well as the header and footer options
      can be passed as [`iodata`](https://hexdocs.pm/elixir/IO.html#module-io-data). Such lists
      are converted to String before submission to the session process by passing them through
      `:erlang.iolist_to_binary/1`.

          ChromicPDF.print_to_pdf(
            {:html, ["<style>p { color: green; }</style>", "<p>green paragraph</p>"]}
          )

      #### Caveats

      Please mind the following caveats.

      ##### References to external files in HTML source

      Please note that since the document content is replaced without navigating to a URL, Chrome
      has no way of telling which host to prepend to **relative URLs** contained in the source.
      This means, if your HTML contains markup like

      ```html
      <!-- BAD: relative link to stylesheet in <head> element -->
      <head>
        <link rel="stylesheet" href="selfhtml.css">
      </head>

      <!-- BAD: relative link to image -->
      <img src="some_logo.png">
      ```

      ... you will need to replace these lines with either **absolute URLs** or inline data.
      Of course, absolute URLs can use the `file://` scheme to point to files on the local
      filesystem, assuming Chrome has access to them. For the purpose of displaying small
      inline images (e.g. logos), [data URLs](https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/Data_URIs)
      are a good way of embedding them without the need for an absolute URL.

      ```html
      <!-- GOOD: inline styles -->
      <style>
        /* ... */
      </style>

      <!-- GOOD: data URLs -->
      <img src="data:image/png;base64,R0lGODdhEA...">

      <!-- GOOD: absolute URLs -->
      <img src="http://localhost/path/to/image.png">
      <img src="file:///path/to/image.png">
      ```

      ##### Content from Phoenix templates

      If your content is generated by a Phoenix template (and hence comes in the form of
      `{:safe, iodata()}`), you will need to pass it to `Phoenix.HTML.safe_to_string/1` first.

          content = SomeView.render("body.html") |> Phoenix.HTML.safe_to_string()
          ChromicPDF.print_to_pdf({:html, content})

      ## Concatenating multiple sources

      Pass a list of sources as first argument to instruct ChromicPDF to create a PDF file for
      each source and concatenate these using Ghostscript. This is particularly useful when some
      sections of your final document require a different page layout than others. You may use
      `ChromicPDF.Template` or tuple sources.

          [
            ChromicPDF.Template.source_and_options(
              content: "<h1>First part with header</h1>",
              header_height: "20mm",
              header: "<p>Some header text</p>"
            ),
            {:html, "second part without header"}
          ]
          |> ChromicPDF.print_to_pdf()

      You can pass additional options to `print_to_pdf/2` as usual, e.g. `:output` to control
      the return value handling.

      Individual sources are processed sequentially and eventually concatenated, so expect runtime
      to increase linearly with the number of sources. The session timeout is applied per source.
      Each source emits the normal `:print_to_pdf` telemetry events. The final concatenation emits
      `:join_pdfs` events.

      Please note that running PDF files through Ghostscript removes all structural annotations
      ("Tags") and hence disables accessibility features of assistive technologies. See
      [On Accessibility / PDF/UA](#module-on-accessibility-pdf-ua) section for details.

      ## Custom options for `Page.printToPDF`

      You can provide custom options for the [`Page.printToPDF`](https://chromedevtools.github.io/devtools-protocol/tot/Page/#method-printToPDF)
      call by passing a map to the `:print_to_pdf` option.

          ChromicPDF.print_to_pdf(
            {:url, "file:///example.html"},
            print_to_pdf: %{
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
              # this is just a basic example. Also, take a look at the documentation for the
              # ChromicPDF.Template module.
              # The <span> classes shown below are interpolated by Chrome.
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
            }
          )

      Please note the **camel-case**. For a full list of options, please see the Chrome
      documentation at:

      https://chromedevtools.github.io/devtools-protocol/tot/Page#method-printToPDF

      ### Page size and margins

      Chrome will use the provided `pagerWidth` and `paperHeight` dimensions as the PDF paper
      format. Please be aware that the `@page` section in the body CSS is not correctly
      interpreted, see `ChromicPDF.Template` for a discussion.

      ### Header and footer

      Chrome's support for native header and footer sections is a little bit finicky. Still, to
      the best of my knowledge, Chrome is currently the only well-functioning solution for
      HTML-to-PDF conversion if you need headers or footers that are repeated on multiple pages
      even in the presence of body elements stretching across a page break.

      In order to make header and footer visible in the first place, you will need to be aware of
      a couple of caveats:

      * You can not use any external (`http://` or `https://`) resources in the header or footer,
        not even per absolute URL. You need to inline all your CSS and convert your images to
        data-URLs.
      * Javascript is not interpreted either.
      * HTML for header and footer is interpreted in a new page context which means no body
        styles will be applied. In fact, even default browser styles are not present, so all
        content will have a default `font-size` of zero, and so on.
      * You need to make space for the header and footer templates first, by adding page margins.
        Margins can either be given using the `marginTop` and `marginBottom` options or with CSS
        styles. If you use the options, the height of header and footer elements will inherit
        these values. If you use CSS styles, make sure to set the height of the elements in CSS
        as well.
      * Header and footer have a default *padding* to the page ends of 0.4 centimeters. To remove
        this, add the following to header/footer template styles [(source)](https://github.com/puppeteer/puppeteer/issues/4132).

            #header, #footer { padding: 0 !important; }

      * Header and footer have a default `zoom` level of 1/0.75 so everything appears to be
        smaller than in the body when the same styles are applied.
      * If header or footer are not displayed even though they should, make sure your HTML is
        valid. Tuning the margins for an hour looking for mistakes there, only to discover that
        you are missing a closing `</style>` tag, can be quite painful.
      * Background colors are not applied unless you include `-webkit-print-color-adjust: exact`
        in your stylesheet.

      See [`print_header_footer_template.html`](https://cs.chromium.org/chromium/src/components/printing/resources/print_header_footer_template_page.html)
      from the Chromium sources to see how these values are interpreted.

      ### Dynamic Content

      #### Evaluate script before printing

      In case your print source is generated by client-side scripts, for instance to render
      graphics or load additional resources, you can trigger these by evaluating a JavaScript
      expression before the PDF is printed.

          evaluate = %{
            expression: """
            document.querySelector('body').innerHTML = 'hello world';
            """
          }

          ChromicPDF.print_to_pdf({:url, "http://example.net"}, evaluate: evaluate)

      If your script returns a Promise, Chrome will wait for it to be resolved.

      #### Wait for attribute on element

      Some JavaScript libraries signal their successful initialization to the user by setting an
      attribute on a DOM element. The `wait_for` option allows you to wait for this attribute to
      be set before printing. It evaluates a script that repeatedly queries the element given by
      the query selector and tests whether it has the given attribute.

          wait_for = %{
            selector: "#my-element",
            attribute: "ready-to-print"
          }

          ChromicPDF.print_to_pdf({:url, "http:///example.net"}, wait_for: wait_for)
      '''
      @spec print_to_pdf(source() | [source()]) :: export_return()
      @spec print_to_pdf(source() | [source()], [pdf_option() | export_option()]) ::
              export_return()
      def print_to_pdf(source, opts \\ []) do
        with_services(&API.print_to_pdf(&1, source, opts))
      end

      @doc """
      Captures a screenshot.

      This call blocks until the screenshot has been created.

      ## Print and return Base64-encoded PNG

          {:ok, blob} = ChromicPDF.capture_screenshot({:url, "file:///example.html"})

      ## Custom options for `Page.captureScreenshot`

      Custom options for the [`Page.captureScreenshot`](https://chromedevtools.github.io/devtools-protocol/tot/Page/#method-captureScreenshot)
      call can be specified by passing a map to the `:capture_screenshot` option.

          ChromicPDF.capture_screenshot(
            {:url, "file:///example.html"},
            capture_screenshot: %{
              format: "jpeg"
            }
          )

      For navigational options (source, cookies, evaluating scripts) see `print_to_pdf/2`.

      You may also use `ChromicPDF.Template` as an input source for `capture_screenshot/2`, yet
      keep in mind that many of the page-related styles do not take effect for screenshots.
      """
      @spec capture_screenshot(source()) :: export_return()
      @spec capture_screenshot(source(), [capture_screenshot_option() | export_option()]) ::
              export_return()
      def capture_screenshot(source, opts \\ []) do
        with_services(&API.capture_screenshot(&1, source, opts))
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

      Generated files pass the [verapdf](https://verapdf.org/) validation. When you verify this,
      please pass the corresponding profile arguments (`-f 2b` or `-f 3b`).

      ## Specifying PDF metadata

      The converter is able to transfer PDF metadata (the `Info` dictionary) from the original
      PDF file to the output file. However, files printed by Chrome do not contain any metadata
      information (except "Creator" being "Chrome").

      The `:info` option of the PDF/A converter allows to specify metadata for the output file
      directly.

          ChromicPDF.convert_to_pdfa("some_pdf_file.pdf", info: %{creator: "ChromicPDF"})

      The converter understands the following keys, all of which accept String values:

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
      step.

          ChromicPDF.convert_to_pdfa(
            "some_pdf_file.pdf",
            pdfa_def_ext: "[/Title (OverriddenTitle) /DOCINFO pdfmark",
          )

      If your extra Postscript requires read permissions for additional files, pass the
      `:permit_read` option.

          ChromicPDF.convert_to_pdfa(
            "some_pdf_file.pdf",
            pdfa_def_ext: "custom-postscript",
            permit_read: "/some/path",
            permit_read: "/some/other/path"
          )

      ## Embedded color scheme

      Since it is required to embed a color scheme into PDF/A files, ChromicPDF ships with a copy of
      the royalty-free [`eciRGB_V2`](http://www.eci.org/) scheme by the European Color Initiative.
      If you need to to use a different color scheme, please open an issue.

      ## Accessibility

      Please note that running a PDF file through Ghostscript removes all structural annotations
      ("Tags") and hence disables accessibility features of assistive technologies. See
      [On Accessibility / PDF/UA](#module-on-accessibility-pdf-ua) section for details.
      """
      @spec convert_to_pdfa(path()) :: export_return()
      @spec convert_to_pdfa(path(), [pdfa_option()]) :: export_return()
      def convert_to_pdfa(pdf_path, opts \\ []) do
        with_services(&API.convert_to_pdfa(&1, pdf_path, opts))
      end

      @doc """
      Prints a PDF and converts it to PDF/A in a single call.

      See `print_to_pdf/2` and `convert_to_pdfa/2` for options.

      ## Example

          ChromicPDF.print_to_pdfa({:url, "https://example.net"})
      """
      @spec print_to_pdfa(source() | [source()]) :: export_return()
      @spec print_to_pdfa(source() | [source()], [pdf_option() | pdfa_option() | export_option()]) ::
              export_return()
      def print_to_pdfa(source, opts \\ []) do
        with_services(&API.print_to_pdfa(&1, source, opts))
      end

      @doc """
      Retrieves the currently set name (set using `put_dynamic_name/1`) or the default name.
      """
      @spec get_dynamic_name() :: atom()
      def get_dynamic_name do
        Process.get({__MODULE__, :dynamic_name}, __MODULE__)
      end

      @doc """
      Activate a particular ChromicPDF instance, which was started with the `name` option.
      After calling this function, all calls in the current process will use this instance of ChromicPDF.

      You can use this function if you need to run ChromicPDF as part of a supervision tree with a
      particular name, for example:

          defmodule MySupervisor do
            use Supervisor

            @impl true
            def init(opts) do
              children = [
                # other apps...
                {ChromicPDF, name: MyName}
              ]

              Supervisor.init(children, strategy: :one_for_one, name: MyApp.Supervisor)
            end
          end

      Returns the previously set name or the default name.
      """
      @spec put_dynamic_name(atom()) :: atom()
      def put_dynamic_name(name) when is_atom(name) do
        Process.put({__MODULE__, :dynamic_name}, name) || __MODULE__
      end

      defp with_services(fun) do
        ChromicPDF.Supervisor.with_services(get_dynamic_name(), fun)
      end
    end
  end
end
