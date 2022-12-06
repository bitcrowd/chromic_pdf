# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.ChromeImpl do
  @moduledoc false

  @behaviour ChromicPDF.Chrome

  def spawn(opts) do
    port = Port.open({:spawn, chrome_command(opts)}, port_opts(opts))
    Port.monitor(port)

    {:ok, port}
  end

  def send_msg(port, msg) do
    send(port, {self(), {:command, msg <> "\0"}})

    :ok
  end

  # --------------------------- Chrome Command Line ----------------------------------
  #
  # For the most part, this list is shamelessly stolen from Puppeteer. Kudos to the Puppeteer team
  # for figuring all these out.
  #
  #   https://github.com/puppeteer/puppeteer/blob/main/packages/puppeteer-core/src/node/ChromeLauncher.ts
  #
  # Some of this may arguably be cargo cult. Some options have since become the default in newer
  # Chrome versions (e.g. --export-tagged-pdf since Chrome 91) but they're kept around to support
  # older browsers.
  #
  # We do not have the --disable-dev-shm-usage option set (as historically it worked without),
  # instead the targetCrashed exception handler explains that it can be set in case of shared
  # memory exhaustion.
  #
  # For a description of the options, see
  #
  #   https://github.com/GoogleChrome/chrome-launcher/blob/main/docs/chrome-flags-for-tools.md
  #   https://peter.sh/experiments/chromium-command-line-switches/
  #
  # One major difference is that we're connecting to Chrome via the newer --remote-debugging-pipe
  # option (i.e. via pipes) instead of via a socket.
  #
  # NOTE: The redirection is needed due to obscure behaviour of Ports that use more than 2 FDs.
  # https://github.com/bitcrowd/chromic_pdf/issues/76
  #
  defp chrome_command(opts) do
    [
      ~s("#{chrome_executable(opts[:chrome_executable])}"),
      "--remote-debugging-pipe",
      "--headless",
      "--disable-accelerated-2d-canvas",
      "--disable-gpu",
      "--allow-pre-commit-input",
      "--disable-background-networking",
      "--disable-background-timer-throttling",
      "--disable-backgrounding-occluded-windows",
      "--disable-breakpad",
      "--disable-client-side-phishing-detection",
      "--disable-component-extensions-with-background-pages",
      "--disable-component-update",
      "--disable-default-apps",
      "--disable-extensions",
      "--disable-features=Translate,BackForwardCache,AcceptCHFrame,MediaRouter,OptimizationHints",
      "--disable-hang-monitor",
      "--disable-ipc-flooding-protection",
      "--disable-popup-blocking",
      "--disable-prompt-on-repost",
      "--disable-renderer-backgrounding",
      "--disable-sync",
      "--enable-automation",
      "--enable-features=NetworkServiceInProcess2",
      "--export-tagged-pdf",
      "--force-color-profile=srgb",
      "--metrics-recording-only",
      "--no-default-browser-check",
      "--no-first-run",
      "--no-service-autorun",
      "--password-store=basic",
      "--use-mock-keychain"
    ]
    |> append_if("--no-sandbox --no-zygote", no_sandbox?(opts))
    |> append_if(to_string(opts[:chrome_args]), !!opts[:chrome_args])
    |> append_if("2>/dev/null 3<&0 4>&1", discard_stderr?(opts))
    |> Enum.join(" ")
  end

  defp port_opts(opts) do
    append_if([:binary], :nouse_stdio, !discard_stderr?(opts))
  end

  defp append_if(list, _value, false), do: list
  defp append_if(list, value, true), do: list ++ [value]

  defp no_sandbox?(opts), do: Keyword.get(opts, :no_sandbox, false)
  defp discard_stderr?(opts), do: Keyword.get(opts, :discard_stderr, true)

  @chrome_paths [
    "chromium-browser",
    "chromium",
    "google-chrome",
    "/usr/bin/chromium-browser",
    "/usr/bin/chromium",
    "/usr/bin/google-chrome",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Chromium.app/Contents/MacOS/Chromium"
  ]

  defp chrome_executable(nil) do
    executable =
      @chrome_paths
      |> Stream.map(&System.find_executable/1)
      |> Enum.find(& &1)

    executable || raise "could not find executable from #{inspect(@chrome_paths)}"
  end

  defp chrome_executable(executable) when is_binary(executable) do
    System.find_executable(executable) || raise "could not find chrome executable #{executable}"
  end
end
