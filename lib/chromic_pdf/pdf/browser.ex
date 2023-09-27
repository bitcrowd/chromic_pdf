# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.Browser do
  @moduledoc false

  use Supervisor
  import ChromicPDF.Utils, only: [find_supervisor_child!: 2, supervisor_children: 2]
  alias ChromicPDF.Browser.{Channel, ExecutionError, SessionPool, SessionPoolConfig}
  alias ChromicPDF.{CloseTarget, Protocol, SpawnSession}

  # ------------- API ----------------

  @spec start_link(Keyword.t()) :: Supervisor.on_start()
  def start_link(config) do
    Supervisor.start_link(__MODULE__, config)
  end

  @spec new_protocol(pid(), module(), keyword()) :: {:ok, any()} | {:error, term()}
  def new_protocol(supervisor, protocol_mod, params) do
    {session_pool, pool_config} = find_session_pool_with_config(supervisor, params)

    checkout_opts = [
      skip_session_use_count: Keyword.get(params, :skip_session_use_count, false),
      timeout: Keyword.fetch!(pool_config, :checkout_timeout)
    ]

    SessionPool.checkout!(session_pool, checkout_opts, fn %{session_id: session_id} ->
      protocol = protocol_mod.new(session_id, Keyword.merge(pool_config, params))
      timeout = Keyword.fetch!(pool_config, :timeout)

      run_protocol(supervisor, protocol, timeout)
    end)
  end

  # ------------ Callbacks -----------

  @impl Supervisor
  def init(config) do
    children = [{Channel, config} | session_pools(config)]

    Supervisor.init(children, strategy: :one_for_all)
  end

  defp session_pools(config) do
    browser = self()

    pools = SessionPoolConfig.pools_from_config(config)
    agent = {Agent, fn -> Map.new(pools) end}

    pools =
      for {id, pool_config} <- pools do
        {SessionPool,
         {id,
          pool_size: Keyword.fetch!(pool_config, :size),
          max_uses: Keyword.fetch!(pool_config, :max_uses),
          init_worker: fn ->
            protocol = SpawnSession.new(pool_config)
            timeout = Keyword.fetch!(pool_config, :init_timeout)

            {:ok, %{"sessionId" => sid, "targetId" => tid}} =
              run_protocol(browser, protocol, timeout)

            %{session_id: sid, target_id: tid}
          end,
          terminate_worker: fn %{target_id: target_id} ->
            protocol = CloseTarget.new(targetId: target_id)
            timeout = Keyword.fetch!(pool_config, :close_timeout)

            {:ok, _} = run_protocol(browser, protocol, timeout)
          end}}
      end

    [agent | pools]
  end

  # ---------- Dealing with supervisor children -----------

  defp run_protocol(supervisor, %Protocol{} = protocol, timeout) do
    supervisor
    |> find_channel()
    |> Channel.run_protocol(protocol, timeout)
  end

  defp find_agent(supervisor), do: find_supervisor_child!(supervisor, Agent)
  defp find_channel(supervisor), do: find_supervisor_child!(supervisor, Channel)

  defp find_session_pool_with_config(supervisor, params) do
    name = SessionPoolConfig.pool_name_from_params(params)

    pool =
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

    config =
      supervisor
      |> find_agent()
      |> Agent.get(& &1)
      |> Map.fetch!(name)

    {pool, config}
  end
end
