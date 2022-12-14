defmodule Benchmark2 do
  @workers 5

  def run do
    Utils.kill_processes!()
    {:ok, _} = ChromicPDF.start_link(session_pool: [size: @workers])
    {:ok, _} = ThroughputMeter.start_link(with_memory: true)

    Enum.map(1..@workers, fn _ ->
      spawn(&print_and_notify_loop/0)
    end)
  end

  defp print_and_notify_loop do
    {:ok, _blob} = ChromicPDF.print_to_pdf({:html, Utils.content("long")})
    ThroughputMeter.bump()
    print_and_notify_loop()
  end
end
