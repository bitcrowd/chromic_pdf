# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.JsonRPC do
  @moduledoc false

  @type call_id :: integer()
  @type session_id :: binary()
  @type method :: binary()
  @type params :: map()

  @type message :: map()

  @type call :: browser_call() | session_call()
  @type browser_call :: {method(), params()}
  @type session_call :: {session_id(), method(), params()}

  if Application.compile_env(:chromic_pdf, :debug_protocol) do
    defmodule JasonWithDebugLogging do
      @moduledoc false
      require Logger

      def encode!(data) do
        Logger.debug("[ChromicPDF] msg out: #{inspect(data)}")
        Jason.encode!(data)
      end

      def decode!(msg) do
        data = Jason.decode!(msg)
        Logger.debug("[ChromicPDF] msg in: #{inspect(data)}")
        data
      end
    end

    @jason JasonWithDebugLogging
  else
    @jason Jason
  end

  @spec encode(call(), call_id()) :: binary()
  def encode({method, params}, call_id) do
    @jason.encode!(%{
      "method" => method,
      "params" => params,
      "id" => call_id
    })
  end

  def encode({session_id, method, params}, call_id) do
    @jason.encode!(%{
      "sessionId" => session_id,
      "method" => method,
      "params" => params,
      "id" => call_id
    })
  end

  @spec decode(binary()) :: message()
  def decode(data), do: @jason.decode!(data)

  @spec response?(message(), call_id()) :: boolean()
  def response?(msg, call_id) do
    (Map.has_key?(msg, "result") or Map.has_key?(msg, "error")) and
      msg["id"] == call_id
  end

  @spec notification?(message(), method()) :: boolean()
  def notification?(msg, method) do
    Map.has_key?(msg, "method") && msg["method"] == method
  end

  @spec is_error?(message()) :: boolean()
  def is_error?(msg) do
    Map.has_key?(msg, "error")
  end

  @spec extract_error(message()) :: String.t()
  def extract_error(%{"error" => error}) do
    "#{error["message"]} (Code #{error["code"]})"
  end
end
