defmodule ChromicPDF.GhostscriptPool do
  @moduledoc false

  alias ChromicPDF.GhostscriptWorker

  @cores System.schedulers_online()
  @default_pool_size Application.get_env(:chromic_pdf, :default_pool_size, div(@cores, 2))
  @default_timeout Application.get_env(:chromic_pdf, :default_timeout, 5000)

  @spec convert(atom(), binary(), keyword(), binary(), keyword()) :: :ok
  # Converts a PDF to PDF-A/2 using Ghostscript.
  def convert(chromic, pdf_path, params, output_path, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    :poolboy.transaction(
      pool_name(chromic),
      &GhostscriptWorker.convert(&1, pdf_path, params, output_path),
      timeout
    )
  end

  @spec child_spec(keyword()) :: :supervisor.child_spec()
  def child_spec(args) do
    pool_name =
      args
      |> Keyword.fetch!(:chromic)
      |> pool_name()

    pool_args = Keyword.get(args, :ghostscript_pool, [])

    :poolboy.child_spec(
      pool_name,
      Keyword.merge(pool_args(pool_name), pool_args),
      args
    )
  end

  defp pool_args(pool_name) do
    [
      name: {:local, pool_name},
      worker_module: ChromicPDF.GhostscriptWorker,
      size: @default_pool_size,
      max_overflow: 0
    ]
  end

  defp pool_name(chromic) do
    Module.concat(chromic, :GhostscriptPool)
  end
end
