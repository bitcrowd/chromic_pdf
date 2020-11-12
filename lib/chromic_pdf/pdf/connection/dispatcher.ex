defmodule ChromicPDF.Connection.Dispatcher do
  @moduledoc false

  alias ChromicPDF.Connection.JsonRPC

  @chrome Application.compile_env(:chromic_pdf, :chrome, ChromicPDF.ChromeImpl)

  @enforce_keys [:port, :next_call_id]
  defstruct [:port, :next_call_id]

  @type t :: %__MODULE__{port: port(), next_call_id: non_neg_integer()}

  def init(port) do
    %__MODULE__{port: port, next_call_id: 1}
  end

  def dispatch(%__MODULE__{port: port, next_call_id: call_id} = state, call) do
    @chrome.send_msg(port, JsonRPC.encode(call, call_id))

    {call_id, %{state | next_call_id: call_id + 1}}
  end
end
