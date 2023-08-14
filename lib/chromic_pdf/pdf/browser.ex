# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.Browser do
  @moduledoc false

  use Supervisor
  import ChromicPDF.Utils, only: [find_supervisor_child!: 2, supervisor_children: 2]
  alias ChromicPDF.Browser.{Channel, ExecutionError, SessionPool}

  # ------------- API ----------------

  @spec start_link(Keyword.t()) :: Supervisor.on_start()
  def start_link(config) do
    Supervisor.start_link(__MODULE__, config)
  end

  @spec channel(pid()) :: pid()
  def channel(supervisor), do: find_supervisor_child!(supervisor, Channel)

  @spec run_protocol(pid(), module(), keyword()) :: {:ok, any()} | {:error, term()}
  def run_protocol(supervisor, protocol, params) do
    supervisor
    |> session_pool(params)
    |> SessionPool.run_protocol(protocol, params)
  end

  defp session_pool(supervisor, params) do
    name = SessionPool.pool_name_from_params(params)

    supervisor
    |> supervisor_children(SessionPool)
    |> Enum.find(fn {{SessionPool, id}, _pid} -> id == name end)
    |> case do
      {_, pid} ->
        pid

      nil ->
        raise ExecutionError, """
        Could not find session pool named #{inspect(name)}!"
        """
    end
  end

  # ------------ Callbacks -----------

  @impl Supervisor
  def init(config) do
    children = [{Channel, config} | session_pools(config)]

    Supervisor.init(children, strategy: :one_for_all)
  end

  defp session_pools(config) do
    for opts <- SessionPool.pools_from_config(config) do
      {SessionPool, opts}
    end
  end
end
