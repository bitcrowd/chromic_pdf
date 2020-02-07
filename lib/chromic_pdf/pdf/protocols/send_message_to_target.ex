defmodule ChromicPDF.SendMessageToTarget do
  @moduledoc false

  # Protocol sends a message to Chrome target and exits immediately.

  use ChromicPDF.Protocol

  @impl ChromicPDF.Protocol
  def init(_from, {session_id, msg}, dispatcher) do
    dispatcher.({
      "Target.sendMessageToTarget",
      %{"message" => msg, "sessionId" => session_id}
    })

    {:done, :ok}
  end
end
