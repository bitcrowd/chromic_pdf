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

  # disables the @doc for child_spec/1
  @doc false
  use Supervisor
  import ChromicPDF.Utils, only: [find_supervisor_child: 2]
  alias ChromicPDF.{Browser, GhostscriptPool}

  @type services :: %{
          browser: pid(),
          ghostscript_pool: pid()
        }

  defp on_demand?(config), do: Keyword.get(config, :on_demand, false)
  defp on_demand_name(chromic), do: Module.concat(chromic, :OnDemand)

  @doc """
  Returns a specification to start this module as part of a supervision tree.
  """
  @spec child_spec([ChromicPDF.global_option()]) :: Supervisor.child_spec()
  def child_spec(chromic, config) do
    type =
      if on_demand?(config) do
        :worker
      else
        :supervisor
      end

    %{
      id: chromic,
      start: {chromic, :start_link, [config]},
      type: type
    }
  end

  @doc false
  @spec start_link(module(), [ChromicPDF.global_option()]) ::
          Supervisor.on_start() | Agent.on_start()
  def start_link(chromic, config \\ []) do
    if on_demand?(config) do
      Agent.start_link(
        fn ->
          config
          |> Keyword.update(:session_pool, [size: 1], &Keyword.put(&1, :size, 1))
          |> Keyword.update(:ghostscript_pool, [size: 1], &Keyword.put(&1, :size, 1))
          |> Keyword.delete(:on_demand)
        end,
        name: on_demand_name(chromic)
      )
    else
      Supervisor.start_link(__MODULE__, config, name: chromic)
    end
  end

  @doc false
  @impl Supervisor
  def init(config) do
    children = [
      {Browser, config},
      {GhostscriptPool, config}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Fetches pids of the supervisor's services and passes them to the given callback function.

  If the supervisor has not been started but configured to run in `on_demand` mode, this will
  start a temporary supervision tree.
  """
  @spec with_services(module(), (services() -> any())) :: any()
  def with_services(chromic, fun) do
    with_supervisor(chromic, fn supervisor ->
      fun.(%{
        browser: find_supervisor_child(supervisor, Browser),
        ghostscript_pool: find_supervisor_child(supervisor, GhostscriptPool)
      })
    end)
  end

  defp with_supervisor(chromic, fun) do
    with {_, nil} <- {chromic, Process.whereis(chromic)},
         {_, nil} <- {:on_demand, Process.whereis(on_demand_name(chromic))} do
      raise("""
      ChromicPDF isn't running and no :on_demand config loaded.

      Please make sure to start its supervisor as part of your application.

          def start(_type, _args) do
            children = [
              # other apps...
              #{__MODULE__ |> to_string() |> String.replace("Elixir.", "")}
            ]

            Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
          end
      """)
    else
      {^chromic, pid} -> fun.(pid)
      {:on_demand, pid} -> pid |> Agent.get(& &1) |> with_on_demand_supervisor(fun)
    end
  end

  defp with_on_demand_supervisor(config, fun) do
    {:ok, sup} = Supervisor.start_link(__MODULE__, config)

    try do
      fun.(sup)
    after
      Supervisor.stop(sup)
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
      @type blob :: iodata()

      @type source :: {:url, url()} | {:html, blob()}
      @type source_and_options :: %{source: source(), opts: [pdf_option()]}

      @type output_function_result :: any()
      @type output_function :: (blob() -> output_function_result())
      @type output_option :: {:output, binary()} | {:output, output_function()}

      @type return :: :ok | {:ok, binary()} | {:ok, output_function_result()}

      @type telemetry_metadata_option :: {:telemetry_metadata, map()}

      @type info_option ::
              {:info,
               %{
                 optional(:title) => binary(),
                 optional(:author) => binary(),
                 optional(:subject) => binary(),
                 optional(:keywords) => binary(),
                 optional(:creator) => binary(),
                 optional(:creation_date) => binary(),
                 optional(:mod_date) => binary()
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
              | output_option()
              | telemetry_metadata_option()

      @type pdfa_option ::
              {:pdfa_version, binary()}
              | {:pdfa_def_ext, binary()}
              | info_option()
              | output_option()
              | telemetry_metadata_option()

      @type capture_screenshot_option ::
              {:capture_screenshot, map()}
              | navigate_option()
              | output_option()
              | telemetry_metadata_option()

      @type session_pool_option ::
              {:size, non_neg_integer()}
              | {:init_timeout, timeout()}
              | {:timeout, timeout()}
      @type ghostscript_pool_option :: {:size, non_neg_integer()}

      @type global_option ::
              {:offline, boolean()}
              | {:max_session_uses, non_neg_integer()}
              | {:session_pool, [session_pool_option()]}
              | {:no_sandbox, boolean()}
              | {:discard_stderr, boolean()}
              | {:chrome_args, binary()}
              | {:chrome_executable, binary()}
              | {:ignore_certificate_errors, boolean()}
              | {:ghostscript_pool, [ghostscript_pool_option()]}
              | {:on_demand, boolean()}

      @doc """
      Returns a specification to start this module as part of a supervision tree.
      """
      @spec child_spec([global_option()]) :: Supervisor.child_spec()
      def child_spec(config), do: ChromicPDF.Supervisor.child_spec(__MODULE__, config)

      @doc """
      Starts ChromicPDF.

      If the given config includes the `on_demand: true` flag, this will instead spawn an
      Agent process that holds this configuration until a PDF operation is triggered which
      will then launch a supervisor temporarily, process the operation, and proceed to perform
      a graceful shutdown.
      """
      @spec start_link([global_option()]) :: Supervisor.on_start() | Agent.on_start()
      def start_link(config \\ []), do: ChromicPDF.Supervisor.start_link(__MODULE__, config)

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

          ChromicPDF.print_to_pdf({:url, "http:///example.net"})

          ChromicPDF.print_to_pdf({:url, "https:///example.net"})

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

      ## PDF printing options

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

      Please note the camel-case. For a full list of options to the `printToPDF` function,
      please see the Chrome documentation at:

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
      @spec print_to_pdf(
              input :: source() | source_and_options(),
              opts :: [pdf_option()]
            ) :: return()
      def print_to_pdf(input, opts \\ []) do
        with_services(__MODULE__, &API.print_to_pdf(&1, input, opts))
      end

      @doc """
      Captures a screenshot.

      This call blocks until the screenshot has been created.

      ## Print and return Base64-encoded PNG

          {:ok, blob} = ChromicPDF.capture_screenshot({:url, "file:///example.html"})

      ## Options

      Options to the [`Page.captureScrenshot`](https://chromedevtools.github.io/devtools-protocol/tot/Page/#method-captureScreenshot)
      call can be passed by passing a map to the `:capture_screenshot` option.

          ChromicPDF.capture_screenshot(
            {:url, "file:///example.html"},
            capture_screenshot: %{
              format: "jpeg"
            }
          )

      For navigational options (source, cookies, evaluating scripts) see `print_to_pdf/2`.
      """
      @spec capture_screenshot(url :: source(), opts :: [capture_screenshot_option()]) :: return()
      def capture_screenshot(input, opts \\ []) do
        with_services(__MODULE__, &API.capture_screenshot(&1, input, opts))
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
      step.

          ChromicPDF.convert_to_pdfa(
            "some_pdf_file.pdf",
            pdfa_def_ext: "[/Title (OverriddenTitle) /DOCINFO pdfmark",
          )
      """
      @spec convert_to_pdfa(pdf_path :: path(), opts :: [pdfa_option()]) :: return()
      def convert_to_pdfa(pdf_path, opts \\ []) do
        with_services(__MODULE__, &API.convert_to_pdfa(&1, pdf_path, opts))
      end

      @doc """
      Prints a PDF and converts it to PDF/A in a single call.

      See `print_to_pdf/2` and `convert_to_pdfa/2` for options.

      ## Example

          ChromicPDF.print_to_pdfa({:url, "https://example.net"})
      """
      @spec print_to_pdfa(
              input :: source() | source_and_options(),
              opts :: [pdf_option() | pdfa_option()]
            ) :: return()
      def print_to_pdfa(input, opts \\ []) do
        with_services(__MODULE__, &API.print_to_pdfa(&1, input, opts))
      end
    end
  end
end
