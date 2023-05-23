# SPDX-License-Identifier: Apache-2.0

# credo:disable-for-this-file Credo.Check.Design.AliasUsage
defmodule ChromicPDF.Connection do
  @moduledoc false

  @type state :: map()
  @type msg :: binary()

  @callback start_link(keyword()) :: {:ok, pid()}
  @callback handle_init(keyword()) :: {:ok, state()}
  @callback handle_msg(msg(), state()) :: :ok

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    if Keyword.has_key?(opts, :chrome_address) do
      start_inet(opts)
    else
      ChromicPDF.Connection.Local.start_link(opts)
    end
  end

  if Code.ensure_loaded?(WebSockex) do
    defp start_inet(opts), do: ChromicPDF.Connection.Inet.start_link(opts)
  else
    defp start_inet(_opts) do
      raise("""
      `:chrome_address` flag given but websockex is not present.

      Please add :websockex to your application's list of dependencies. Afterwards, please
      recompile ChromicPDF.

          mix deps.compile --force chromic_pdf
      """)
    end
  end

  @spec send_msg(pid(), binary()) :: :ok
  def send_msg(pid, msg) do
    :ok = GenServer.cast(pid, {:msg, msg})
  end

  defmacro __using__(_) do
    quote do
      use GenServer
      alias ChromicPDF.Connection

      @behaviour Connection

      @impl Connection
      def start_link(opts) do
        GenServer.start_link(__MODULE__, {self(), opts})
      end

      @impl GenServer
      def init({channel_pid, opts}) do
        {:ok, state} = handle_init(opts)

        {:ok, Map.put(state, :channel_pid, channel_pid)}
      end

      @impl GenServer
      def handle_cast({:msg, msg}, state) do
        :ok = handle_msg(msg, state)

        {:noreply, state}
      end

      defp send_msg_to_channel(msg, %{channel_pid: channel_pid} = state) do
        send(channel_pid, {:msg, msg})
      end
    end
  end
end
