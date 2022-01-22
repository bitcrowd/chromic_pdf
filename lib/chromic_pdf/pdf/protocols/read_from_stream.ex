defmodule ChromicPDF.ReadFromStream do
  @moduledoc false

  import ChromicPDF.ProtocolMacros

  steps do
    call(:read_from_stream, "IO.read", &read_opts/1, %{})
    await_response(:read_from_stream_done, ["data", "eof"])
    output(["data", "eof"])
  end

  defp read_opts(%{"handle" => handle}) do
    opts = %{"handle" => handle}

    if size = Application.get_env(:chromic_pdf, :stream_read_size) do
      Map.put(opts, "size", size)
    else
      opts
    end
  end
end
