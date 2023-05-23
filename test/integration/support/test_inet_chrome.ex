# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.TestInetChrome do
  @moduledoc false

  use GenServer
  alias ChromicPDF.ChromeRunner

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl GenServer
  def init(opts) do
    inet_port = Keyword.fetch!(opts, :port)
    port = ChromeRunner.port_open(chrome_args: "--remote-debugging-port=#{inet_port}")

    {:ok, %{port: port}}
  end
end
