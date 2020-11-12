defmodule ChromicPDF.Browser do
  @moduledoc false

  use Supervisor
  alias ChromicPDF.Browser.{Channel, SessionPool}

  # ------------- API ----------------

  @spec start_link(Keyword.t()) :: Supervisor.on_start()
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: name(args))
  end

  defp name(args) when is_list(args), do: args |> Keyword.fetch!(:chromic) |> name()
  defp name(chromic) when is_atom(chromic), do: Module.concat(chromic, :Browser)

  @spec channel(pid() | atom()) :: pid()
  def channel(supervisor), do: find_child(supervisor, Channel)

  @spec session_pool(pid() | atom()) :: pid()
  def session_pool(supervisor), do: find_child(supervisor, SessionPool)

  defp find_child(supervisor, module) do
    supervisor
    |> Supervisor.which_children()
    |> Enum.find(fn {mod, _, _, _} -> mod == module end)
    |> elem(1)
  end

  @spec run_protocol(pid() | atom(), module(), keyword()) :: {:ok, any()} | {:error, term()}
  def run_protocol(chromic, protocol, params) when is_atom(chromic) do
    chromic
    |> name()
    |> Process.whereis()
    |> run_protocol(protocol, params)
  end

  def run_protocol(supervisor, protocol, params) when is_pid(supervisor) do
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
