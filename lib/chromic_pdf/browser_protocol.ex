defmodule ChromicPDF.BrowserProtocol do
  @moduledoc false

  @spec spawn_session() :: :ok
  def spawn_session do
    respond_with_chrome_msg(
      "Target.createTarget",
      %{"url" => "about:blank"}
    )
  end

  @spec send_session_msg(session_id :: binary(), msg :: binary()) :: :ok
  def send_session_msg(session_id, msg) do
    respond_with_chrome_msg(
      "Target.sendMessageToTarget",
      %{"sessionId" => session_id, "message" => msg}
    )
  end

  @spec handle_chrome_msg_in(msg :: ChromicPDF.JsonRPCChannel.decoded_message()) :: :ok
  def handle_chrome_msg_in(msg) do
    case msg do
      {:response, "Target.createTarget", result} ->
        respond_with_chrome_msg(
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

  defp respond_with_chrome_msg(method, params) do
    respond({:chrome_msg_out, {:call, method, params}})
  end

  defp respond(msg) do
    send(self(), msg)
    :ok
  end
end
