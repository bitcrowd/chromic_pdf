defmodule ChromicPDF.ReadStream do
  @moduledoc false

  import ChromicPDF.ProtocolMacros

  steps do
    label(:start)

    call(:read_from_stream, "IO.read", [{"handle", "stream"}], %{})
    await_response(:read_from_stream_done, ["data", "eof"])

    # TODO: emit chunk somewhere

    jump(:continue_reading, &continue_reading?/1, :start)
  end

  defp continue_reading?(state) do
    !Map.fetch!(state, "eof")
  end
end
