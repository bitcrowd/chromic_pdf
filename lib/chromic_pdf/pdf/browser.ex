defmodule ChromicPDF.Browser do
  @moduledoc false

  use Supervisor
  import ChromicPDF.Utils, only: [find_supervisor_child: 2]
  alias ChromicPDF.Browser.{Channel, SessionPool}

  # ------------- API ----------------

  @spec start_link(Keyword.t()) :: Supervisor.on_start()
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  @spec channel(pid()) :: pid()
  def channel(supervisor), do: find_supervisor_child(supervisor, Channel)

  @spec session_pool(pid()) :: pid()
  def session_pool(supervisor), do: find_supervisor_child(supervisor, SessionPool)

  @spec spawn_session(pid()) :: Channel.session()
  def spawn_session(supervisor) do
    supervisor
    |> channel()
    |> Channel.spawn_session()
  end

  @spec close_session(pid(), Channel.session()) :: :ok
  def close_session(supervisor, session) do
    supervisor
    |> channel()
    |> Channel.close_session(session)
  end

  @spec run_protocol(pid(), Channel.session(), module(), keyword()) ::
          {:ok, any()} | {:error, term()}
  def run_protocol(supervisor, session, protocol, params) do
    supervisor
    |> channel()
    |> Channel.run_protocol(session, protocol, params)
  end

  @spec checkout_session(pid(), (Channel.session() -> any())) :: any()
  def checkout_session(supervisor, callback) do
    supervisor
    |> session_pool()
    |> SessionPool.checkout!(callback)
  end

  # ------------ Callbacks -----------

  @impl Supervisor
  def init(args) do
    children = [
      {Channel, args},
      {SessionPool, args}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
