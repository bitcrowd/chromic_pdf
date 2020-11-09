defmodule ChromicPDF.Connection.JsonRPC do
  @moduledoc false

  @type call_id :: integer()
  @type session_id :: binary()
  @type method :: binary()
  @type params :: map()

  @type message :: map()

  @type call :: browser_call() | session_call()
  @type browser_call :: {method(), params()}
  @type session_call :: {session_id(), method(), params()}

  @spec encode(call(), call_id()) :: binary()
  def encode({method, params}, call_id) do
    Jason.encode!(%{
      "method" => method,
      "params" => params,
      "id" => call_id
    })
  end

  def encode({session_id, method, params}, call_id) do
    Jason.encode!(%{
      "sessionId" => session_id,
      "method" => method,
      "params" => params,
      "id" => call_id
    })
  end

  @spec decode(binary()) :: message()
  def decode(data), do: Jason.decode!(data)

  @spec is_response?(message(), call_id()) :: boolean()
  def is_response?(msg, call_id) do
    Map.has_key?(msg, "result") && msg["id"] == call_id
  end

  @spec is_notification?(message(), method()) :: boolean()
  def is_notification?(msg, method) do
    Map.has_key?(msg, "method") && msg["method"] == method
  end
end
