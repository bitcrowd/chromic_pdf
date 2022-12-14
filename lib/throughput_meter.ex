defmodule ThroughputMeter do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def bump do
    GenServer.cast(__MODULE__, :bump)
  end

  @impl GenServer
  def init(opts) do
    interval = Keyword.get(opts, :interval, 50)
    with_memory = Keyword.get(opts, :with_memory, false)

    state = %{
      processed: 0,
      interval: interval,
      interval_start: time(),
      with_memory: with_memory
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_cast(:bump, state) do
    {:noreply, state |> bump() |> measure()}
  end

  defp bump(%{processed: processed} = state) do
    %{state | processed: processed + 1}
  end

  defp measure(state) do
    if rem(state.processed, state.interval) == 0 do
      dt = time() - state.interval_start
      ps = Float.round(state.interval / (msec(dt) / 1000), 2)

      IO.puts("#{state.processed} processed, #{ps} jobs/sec")

      if state.with_memory, do: chrome_memory()

      %{state | interval_start: time()}
    else
      state
    end
  end

  defp time, do: System.monotonic_time()
  defp msec(val), do: System.convert_time_unit(val, :native, :millisecond)

  defp chrome_memory do
    # Extract "RSS" from ps output.
    :"ps aux | grep Chrome | awk '{print $6};'"
    |> :os.cmd()
    |> to_string()
    |> String.split("\n")
    |> Enum.reject(& &1 == "")
    |> Enum.map(&String.to_integer/1)
    |> Enum.sum()
    |> IO.inspect(label: "Chrome memory")
  end

end
