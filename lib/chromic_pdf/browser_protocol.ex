defmodule ChromicPDF.BrowserProtocol do
  @moduledoc false

  import ChromicPDF.JsonRPC
  alias ChromicPDF.JsonRPCState

  @type state :: pid()

  defdelegate start_link, to: JsonRPCState

  @spec spawn_session(state()) :: :ok
  def spawn_session(state) do
    respond_with_chrome_msg(
      state,
      "Target.createTarget",
      %{"url" => "about:blank"}
    )
  end

  @spec send_session_msg(state(), session_id :: binary(), msg :: binary()) :: :ok
  def send_session_msg(state, session_id, msg) do
    respond_with_chrome_msg(
      state,
      "Target.sendMessageToTarget",
      %{"sessionId" => session_id, "message" => msg}
    )
  end

  @spec handle_chrome_msg_in(state(), msg :: binary()) :: :ok
  def handle_chrome_msg_in(state, msg) do
    case decode_and_classify(state, msg) do
      {:response, "Target.createTarget", result} ->
        respond_with_chrome_msg(
          state,
          "Target.attachToTarget",
          result
        )

      {:notification, "Target.attachedToTarget", %{"sessionId" => session_id}} ->
        respond({:session_spawned, session_id})

      {:notification, "Target.receivedMessageFromTarget", params} ->
        %{"sessionId" => session_id, "message" => message} = params
        respond({:session_msg_out, session_id, message})

      _anything_else ->
        :ok
    end
  end

  defp respond_with_chrome_msg(state, method, params) do
    msg = encode(state, method, params)
    respond({:chrome_msg_out, msg})
  end

  defp respond(msg) do
    send(self(), msg)
    :ok
  end
end
