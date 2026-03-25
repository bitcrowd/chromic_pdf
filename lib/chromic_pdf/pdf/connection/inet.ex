# SPDX-License-Identifier: Apache-2.0

if Code.ensure_loaded?(WebSockex) do
  defmodule ChromicPDF.Connection.Inet do
    @moduledoc false

    use ChromicPDF.Connection
    alias ChromicPDF.Connection.ConnectionLostError

    defmodule Websocket do
      @moduledoc false

      use WebSockex

      @spec start_link(binary()) :: GenServer.on_start()
      def start_link(websocket_debugger_url) do
        WebSockex.start_link(websocket_debugger_url, __MODULE__, %{parent_pid: self()})
      end

      @impl WebSockex
      def handle_frame({:text, msg}, %{parent_pid: parent_pid} = state) do
        send(parent_pid, {:frame, msg})

        {:ok, state}
      end

      @spec send_frame(pid(), binary()) :: :ok
      def send_frame(pid, msg) do
        :ok = WebSockex.send_frame(pid, {:text, msg})
      end
    end

    @impl ChromicPDF.Connection
    def handle_init(opts) do
      {:ok, ws_pid} =
        opts
        |> Keyword.fetch!(:chrome_address)
        |> websocket_debugger_url()
        |> Websocket.start_link()

      {:ok, %{ws_pid: ws_pid}}
    end

    @impl ChromicPDF.Connection
    def handle_msg(msg, %{ws_pid: ws_pid}) do
      Websocket.send_frame(ws_pid, msg)
    end

    @impl GenServer
    def handle_info({:frame, msg}, state) do
      send_msg_to_channel(msg, state)

      {:noreply, state}
    end

    defp websocket_debugger_url({host, port}) do
      # Ensure inets app is started. Ignore error if it was already.
      :inets.start()

      url = String.to_charlist("http://#{host}:#{port}/json/version")
      # Chrome requires the "host" header to be set to either an ip address or localhost,
      # otherwise it will not accept the connection
      headers = [{~c"accept", ~c"application/json"}, {~c"host", ~c"localhost"}]
      http_request_opts = [ssl: [verify: :verify_none]]

      case :httpc.request(:get, {url, headers}, http_request_opts, []) do
        {:ok, {_, _, body}} ->
          body
          |> Jason.decode!()
          |> Map.fetch!("webSocketDebuggerUrl")
          # replace the "localhost" we've provided using the "host" header with
          # the actual address of the chrome instance
          |> String.replace("localhost", "#{host}:#{port}")


        {:error, {:failed_connect, _}} ->
          raise ConnectionLostError, "failed to connect to #{url}"
      end
    end
  end
end
