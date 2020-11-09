defmodule ChromicPDF.Connection.Dispatcher do
  @moduledoc false

  alias ChromicPDF.Connection.JsonRPC

  @chrome Application.compile_env(:chromic_pdf, :chrome, ChromicPDF.ChromeImpl)

  def init(port) do
    %{port: port, next_call_id: 1}
  end

  def dispatch(call, %{port: port, next_call_id: call_id} = state) do
    @chrome.send_msg(port, JsonRPC.encode(call, call_id))

    {call_id, %{state | next_call_id: call_id + 1}}
  end
end
