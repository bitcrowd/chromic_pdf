defmodule ChromicPDF.SessionPool do
  @moduledoc false

  alias ChromicPDF.Session

  @timeout 5000

  @spec print_to_pdf(atom(), tuple(), keyword()) :: binary()
  def print_to_pdf(chromic, input, opts) do
    transaction(chromic, opts, &Session.print_to_pdf(&1, input, opts))
  end

  @spec capture_screenshot(atom(), tuple(), keyword()) :: binary()
  def capture_screenshot(chromic, input, opts) do
    transaction(chromic, opts, &Session.capture_screenshot(&1, input, opts))
  end

  defp transaction(chromic, opts, fun) do
    timeout = Keyword.get(opts, :timeout, @timeout)
    :poolboy.transaction(pool_name(chromic), fun, timeout)
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
      size: 1,
      max_overflow: 0
    ]
  end

  def pool_name(chromic) do
    Module.concat(chromic, :SessionPool)
  end
end
