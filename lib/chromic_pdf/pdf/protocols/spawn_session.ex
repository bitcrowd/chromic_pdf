defmodule ChromicPDF.SpawnSession do
  @moduledoc false

  # Protocol responsible for spawning targets and attaching to them.
  # Will stay alive indefinitely and route incoming messages to its session.

  use ChromicPDF.Protocol

  @impl ChromicPDF.Protocol
  def init(from, _params, dispatcher) do
    call_id = dispatcher.({"Target.createTarget", %{"url" => "about:blank"}})

    {:ok,
     %{
       from: from,
       step: :create,
       call_id: call_id,
       target_id: nil,
       session_id: nil
     }}
  end

  @impl ChromicPDF.Protocol
  def handle_msg(msg, %{step: :create, call_id: call_id} = state, dispatcher) do
    case msg do
      {:response, ^call_id, result} ->
        call_id = dispatcher.({"Target.attachToTarget", result})
        {:ok, %{state | step: :attach, call_id: call_id}}

      _ ->
        :ignore
    end
  end

  def handle_msg(msg, %{step: :attach, call_id: call_id} = state, _dispatcher) do
    case msg do
      {:response, ^call_id, %{"sessionId" => session_id}} ->
        GenServer.reply(state.from, {:ok, session_id})
        {:ok, %{state | step: :forward, session_id: session_id}}

      _ ->
        :ignore
    end
  end

  def handle_msg(msg, %{step: :forward, session_id: session_id} = state, _dispatcher) do
    case msg do
      {:notification,
       {"Target.receivedMessageFromTarget", %{"sessionId" => ^session_id} = params}} ->
        forward_msg_to_session(Map.get(params, "message"), state)
        {:ok, state}

      _ ->
        :ignore
    end
  end

  defp forward_msg_to_session(msg, %{from: {pid, _ref}}) do
    send(pid, {:msg_in, msg})
  end
end
