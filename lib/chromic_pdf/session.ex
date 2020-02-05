defmodule ChromicPDF.Session do
  @moduledoc false

  use GenServer
  alias ChromicPDF.{Browser, JsonRPCChannel, SessionProtocol}

  # ------------- API ----------------

  @spec start_link(Keyword.t()) :: GenServer.on_start()
  # Called by :poolboy to instantiate the worker process.
  def start_link(worker_args) do
    browser =
      worker_args
      |> Keyword.fetch!(:chromic)
      |> Browser.server_name()

    GenServer.start_link(__MODULE__, browser)
  end

  @spec print_to_pdf(pid(), url :: binary(), params :: map(), output :: binary()) :: :ok
  # Prints a PDF by navigating the session target to a URL.
  def print_to_pdf(pid, url, params, output) do
    GenServer.call(pid, {:print_to_pdf, url, params, output})
  end

  # ------------ Server --------------

  @impl true
  @spec init(browser :: atom()) :: {:ok, map(), {:continue, :enable_page}}
  def init(browser) do
    {:ok, session_id} = Browser.spawn_session(browser)
    {:ok, channel_pid} = JsonRPCChannel.start_link()

    state = %{
      browser: browser,
      session_id: session_id,
      channel: channel_pid,
      request: nil
    }

    {:ok, state, {:continue, :enable_page}}
  end

  @impl true
  def handle_continue(:enable_page, state) do
    SessionProtocol.enable_page_notifications()
    {:noreply, state}
  end

  @impl true
  def handle_call({:print_to_pdf, url, params, output}, from, state) do
    request = %{from: from, params: params, output: output}
    SessionProtocol.start_navigation(url)
    {:noreply, %{state | request: request}}
  end

  @impl true
  def handle_info({:chrome_msg_in, msg}, state) do
    SessionProtocol.handle_chrome_msg_in(JsonRPCChannel.decode(state.channel, msg))
    {:noreply, state}
  end

  def handle_info({:chrome_msg_out, msg}, state) do
    Browser.send_session_msg(
      state.browser,
      state.session_id,
      JsonRPCChannel.encode(state.channel, msg)
    )

    {:noreply, state}
  end

  def handle_info({:navigation_started, frame_id}, state) do
    # Remember the frame that is loading **our** page.
    # There are sometimes other frames loaded (e.g. when you go to google.com,
    # it loads a few iframes that also emit frameStoppedLoading events.
    {:noreply, put_in(state[:request][:frame_id], frame_id)}
  end

  def handle_info({:navigation_finished, frame_id}, state) do
    if state.request && state.request.frame_id == frame_id do
      SessionProtocol.start_printing(state.request.params)
    end

    {:noreply, state}
  end

  def handle_info({:pdf_printed, data}, state) do
    File.write!(state.request.output, Base.decode64!(data))
    GenServer.reply(state.request.from, :ok)
    {:noreply, %{state | request: nil}}
  end
end
