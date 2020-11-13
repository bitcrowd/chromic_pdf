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

  @spec run_protocol(pid(), module(), keyword()) :: {:ok, any()} | {:error, term()}
  def run_protocol(supervisor, protocol, params) do
    supervisor
    |> session_pool()
    |> SessionPool.run_protocol(protocol, params)
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
