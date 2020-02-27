defmodule Example.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      Example.Endpoint,
      ChromicPDF
    ]

    opts = [strategy: :one_for_one, name: Example.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    Example.Endpoint.config_change(changed, removed)
    :ok
  end
end
