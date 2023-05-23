# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.TestDockerChrome do
  @moduledoc false

  use GenServer
  import ChromicPDF.Utils, only: [system_cmd!: 2]
  alias ChromicPDF.ChromeRunner

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def close(pid) do
    GenServer.cast(pid, :close)
  end

  @impl GenServer
  def init(opts) do
    port = Keyword.fetch!(opts, :port)

    port_cmd =
      Enum.join(
        [
          "docker run --rm",
          "-p #{port}:#{port}",
          "--security-opt seccomp=$(pwd)/test/integration/fixtures/chrome-seccomp.json",
          "zenika/alpine-chrome:114",
          "--remote-debugging-port=#{port}",
          "--remote-debugging-address=0.0.0.0"
          | ChromeRunner.default_args()
        ],
        " "
      )

    port = Port.open({:spawn, "#{port_cmd} 2>/dev/null"}, [:binary])
    os_pid = port |> Port.info() |> Keyword.fetch!(:os_pid)

    Process.flag(:trap_exit, true)

    {:ok, %{os_pid: os_pid}}
  end

  @impl GenServer
  def terminate(_reason, %{os_pid: os_pid}) do
    # Docker does not handle EOD on stdin (sent when port is terminated), so kill the process manually.
    system_cmd!("kill", [to_string(os_pid)])
    :ok
  end
end
