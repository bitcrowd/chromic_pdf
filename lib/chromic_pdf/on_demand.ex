defmodule ChromicPDF.OnDemand do
  @moduledoc false

  import ChromicPDF.Utils, only: [find_supervisor_child: 2]

  @spec start_link([ChromicPDF.global_option()]) :: Supervisor.on_start()
  def start_link(config) do
    name =
      config
      |> Keyword.fetch!(:name)
      |> on_demand_name()

    config =
      config
      |> Keyword.update(:session_pool, [size: 1], &Keyword.put(&1, :size, 1))
      |> Keyword.update(:ghostscript_pool, [size: 1], &Keyword.put(&1, :size, 1))
      |> Keyword.delete(:on_demand)

    children = [
      {Agent, fn -> config end},
      {DynamicSupervisor, strategy: :one_for_one}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: name)
  end

  @spec try_on_demand_supervisor(atom(), function()) :: {:found, term()} | :not_found
  def try_on_demand_supervisor(name, fun) do
    if pid = Process.whereis(on_demand_name(name)) do
      config =
        pid
        |> find_supervisor_child(Agent)
        |> Agent.get(& &1)

      {:found, with_temporary_supervisor(pid, config, fun)}
    else
      :not_found
    end
  end

  defp with_temporary_supervisor(sup, config, fun) do
    sup = find_supervisor_child(sup, DynamicSupervisor)

    {:ok, child} = DynamicSupervisor.start_child(sup, {ChromicPDF.Supervisor, config})

    try do
      fun.(child)
    after
      DynamicSupervisor.terminate_child(sup, child)
    end
  end

  defp on_demand_name(chromic), do: Module.concat(chromic, OnDemand)
end
