defmodule ChromicPDF.ChromeImpl do
  @moduledoc false

  import ChromicPDF.Utils, only: [system_cmd!: 2]

  @behaviour ChromicPDF.Chrome

  def spawn(opts) do
    port = Port.open({:spawn, chrome_command(opts)}, [:binary])
    Port.monitor(port)

    {:ok, port}
  end

  def stop(port) do
    with {:os_pid, os_pid} <- Port.info(port, :os_pid) do
      system_cmd!("kill", [to_string(os_pid)])
      Port.close(port)
    end

    :ok
  end

  def send_msg(port, msg) do
    send(port, {self(), {:command, msg <> "\0"}})

    :ok
  end

  # Chrome is started with the "--remote-debugging-pipe" switch
  # and its FD 3 & 4 are redirected to and from stdin and stdout.
  # stderr is silently discarded.
  defp chrome_command(opts) do
    no_sandbox = if Keyword.get(opts, :no_sandbox), do: "--no-sandbox"

    ~s("#{chrome_executable()}" #{no_sandbox} --headless --disable-gpu --remote-debugging-pipe 2>/dev/null 3<&0 4>&1)
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
