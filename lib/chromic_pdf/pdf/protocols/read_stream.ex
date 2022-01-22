defmodule ChromicPDF.ReadStream do
  @moduledoc false

  import ChromicPDF.ProtocolMacros

  steps do
    label(:start)

    call(:read_from_stream, "IO.read", [{"handle", "stream"}], %{})
    await_response(:read_from_stream_done, ["data", "eof"])

    @steps {:call, :process_chunk, 2}

    jump(:continue_reading, &continue_reading?/1, :start)

    call(:close_stream, "IO.close", [{"handle", "stream"}], %{})
    await_response(:stream_closed, [])
  end

  def process_chunk(%{"data" => data, "eof" => eof, :output => output} = state, _dispatch) when is_pid(output) do
    if data != "" do
      send(output, {:data, data})
    end

    if eof do
      send(output, :eof)
    end

    state
  end

  defp continue_reading?(%{"eof" => eof}), do: !eof
end
