defmodule ChromicPDF.ChromeImpl do
  @moduledoc false

  @behaviour ChromicPDF.Chrome

  def spawn(opts) do
    port = Port.open({:spawn, chrome_command(opts)}, [:binary, :nouse_stdio])
    Port.monitor(port)

    {:ok, port}
  end

  def send_msg(port, msg) do
    send(port, {self(), {:command, msg <> "\0"}})

    :ok
  end

  defp chrome_command(opts) do
    ~s("#{chrome_executable()}" #{no_sandbox(opts)} --headless --disable-gpu --remote-debugging-pipe #{
      discard_stderr(opts)
    })
  end

  defp no_sandbox(opts) do
    if Keyword.get(opts, :no_sandbox, false) do
      "--no-sandbox"
    end
  end

  defp discard_stderr(opts) do
    if Keyword.get(opts, :discard_stderr, true) do
      "2>/dev/null"
    end
  end

  @chrome_paths [
    "chromium-browser",
    "chromium",
    "google-chrome",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  ]

  defp chrome_executable do
    executable =
      @chrome_paths
      |> Stream.map(&System.find_executable/1)
      |> Enum.find(& &1)

    executable || raise "could not find executable from #{inspect(@chrome_paths)}"
  end
end
