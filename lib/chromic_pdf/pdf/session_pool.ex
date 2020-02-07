defmodule ChromicPDF.SessionPool do
  @moduledoc false

  alias ChromicPDF.Session

  @default_timeout 5000

  # Creates a PDF using the Chrome Session pool.
  def print_to_pdf(chromic, url, params, output, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    :poolboy.transaction(
      pool_name(chromic),
      &Session.print_to_pdf(&1, url, params, output),
      timeout
    )
  end

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
      size: 5,
      max_overflow: 0
    ]
  end

  def pool_name(chromic) do
    Module.concat(chromic, :SessionPool)
  end
end
