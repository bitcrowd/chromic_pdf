defmodule ChromicPDF.CloseStream do
  @moduledoc false

  import ChromicPDF.ProtocolMacros

  steps do
    call(:close_stream, "IO.close", ["handle"], %{})
    await_response(:stream_closed, [])
    output([])
  end
end
