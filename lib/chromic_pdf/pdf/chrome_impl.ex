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

  # NOTE: The redirection is needed due to obscure behaviour of Ports that use more than 2 FDs.
  # https://github.com/bitcrowd/chromic_pdf/issues/76

  defp chrome_command(opts) do
    [
      ~s("#{chrome_executable(opts[:chrome_executable])}"),
      "--headless --disable-gpu --remote-debugging-pipe"
    ]
    |> append_if("--no-sandbox", no_sandbox?(opts))
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
