# SPDX-License-Identifier: Apache-2.0

defmodule Mix.Tasks.ChromicPdf.WarmUp do
  @moduledoc """
  Runs a one-off Chrome process to allow Chrome to initialize its caches.

  This function mitigates timeout errors on certain CI environments where Chrome would
  occassionally take a long time to respond to the first DevTools commands.

  See `ChromicPDF.warm_up/1` for details.
  """

  use Mix.Task

  @doc false
  @shortdoc "Launches a one-off Chrome process to warm up Chrome's caches"
  @spec run(any()) :: :ok
  def run(_) do
    {usec, _} = :timer.tc(fn -> ChromicPDF.warm_up() end)

    IO.puts("[ChromicPDF] Chrome warm-up finished in #{trunc(usec / 1_000)}ms.")
  end
end
