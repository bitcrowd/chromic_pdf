defmodule ChromicPDF.PrintToPDF do
  @moduledoc false

  import ChromicPDF.ProtocolMacros
  alias ChromicPDF.Protocol

  steps do
    call(:navigate, "Page.navigate", [:url], %{})
    await_response(:navigated, ["frameId"])
    await_notification(:frame_stopped_loading, "Page.frameStoppedLoading", ["frameId"], [])
    call(:print_to_pdf, "Page.printToPDF", & &1[:print_to_pdf_opts], %{})
    await_response(:printed, ["data"])

    @steps {:reply, :persist_and_reply, 1}
    def persist_and_reply(%{"data" => data, :output => output}) do
      File.write!(output, Base.decode64!(data))
      :ok
    end
  end

  @spec new(
          session_id :: binary(),
          params :: %{
            print_to_pdf_opts: map(),
            url: binary(),
            output: binary()
          }
        ) :: Protocol.t()
  def new(session_id, params) do
    build_steps()
    |> Protocol.new(Map.put(params, "sessionId", session_id))
  end
end
