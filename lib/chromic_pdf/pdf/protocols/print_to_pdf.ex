defmodule ChromicPDF.PrintToPDF do
  @moduledoc false

  use ChromicPDF.Protocol

  # Protocol instructs target to navigate to URL, then waits until
  # primary frame has stopped loading, then issues the printToPDF
  # command and collects the result.

  @impl ChromicPDF.Protocol
  def init(from, {url, params, output}, dispatcher) do
    call_id = dispatcher.({"Page.navigate", %{"url" => url}})

    {:ok,
     %{
       from: from,
       step: :navigate,
       call_id: call_id,
       params: params,
       output: output,
       frame_id: nil
     }}
  end

  @impl ChromicPDF.Protocol
  def handle_msg(msg, %{step: :navigate, call_id: call_id} = state, _dispatcher) do
    case msg do
      {:response, ^call_id, %{"frameId" => frame_id}} ->
        {:ok, %{state | step: :frame, frame_id: frame_id}}

      _ ->
        :ignore
    end
  end

  def handle_msg(msg, %{step: :frame, frame_id: frame_id} = state, dispatcher) do
    case msg do
      {:notification, {"Page.frameStoppedLoading", %{"frameId" => ^frame_id}}} ->
        call_id = dispatcher.({"Page.printToPDF", state.params})
        {:ok, %{state | step: :pdf, call_id: call_id}}

      _ ->
        :ignore
    end
  end

  def handle_msg(msg, %{step: :pdf, call_id: call_id} = state, _dispatcher) do
    case msg do
      {:response, ^call_id, %{"data" => data}} ->
        File.write!(state.output, Base.decode64!(data))
        GenServer.reply(state.from, :ok)
        :done

      _ ->
        :ignore
    end
  end
end
