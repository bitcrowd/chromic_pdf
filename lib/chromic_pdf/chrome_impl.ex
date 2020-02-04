defmodule ChromicPDF.ChromeImpl do
  @moduledoc false

  @behaviour ChromicPDF.Chrome

  # Chrome is started with the "--remote-debugging-pipe" switch
  # and its FD 3 & 4 are redirected to and from stdin and stdout.
  # stderr is silently discarded.
  @chrome_bin "\"/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome\""
  @chrome_cmd "#{@chrome_bin} --headless --disable-gpu --remote-debugging-pipe 2>/dev/null 3<&0 4>&1"

  def spawn do
    port = Port.open({:spawn, @chrome_cmd}, [:binary])
    Port.monitor(port)

    {:ok, port}
  end

  def stop(port) do
    if Port.info(port), do: Port.close(port)

    :ok
  end

  def send_msg(port, msg) do
    send(port, {self(), {:command, msg <> "\0"}})

    :ok
  end
end
