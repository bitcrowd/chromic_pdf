defmodule ChromicPDF.SessionPool do
  @moduledoc false

  alias ChromicPDF.Session

  @cores System.schedulers_online()
  @default_pool_size Application.get_env(:chromic_pdf, :default_pool_size, div(@cores, 2))
  @default_timeout Application.get_env(:chromic_pdf, :default_timeout, 5000)

  @spec run_protocol(atom(), module(), keyword()) :: {:ok, any()} | {:error, term()}
  def run_protocol(chromic, protocol_mod, opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    :poolboy.transaction(
      pool_name(chromic),
      &Session.run_protocol(&1, protocol_mod, opts),
      timeout
    )
  end

  @spec child_spec(keyword()) :: :supervisor.child_spec()
  def child_spec(args) do
    pool_name =
      args
      |> Keyword.fetch!(:chromic)
      |> pool_name()

    pool_args = Keyword.get(args, :session_pool, [])

    :poolboy.child_spec(
      pool_name,
      Keyword.merge(pool_args(pool_name), pool_args),
      args
    )
  end

  defp pool_args(pool_name) do
    [
      name: {:local, pool_name},
      worker_module: ChromicPDF.Session,
      size: @default_pool_size,
      max_overflow: 0
    ]
  end

  def pool_name(chromic) do
    Module.concat(chromic, :SessionPool)
  end
end
