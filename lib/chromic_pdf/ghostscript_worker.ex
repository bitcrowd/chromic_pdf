defmodule ChromicPDF.GhostscriptWorker do
  @moduledoc false

  use GenServer
  alias ChromicPDF.Ghostscript

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(_) do
    {:ok, nil}
  end

  def convert(pid, pdf_path, output_path) do
    GenServer.call(pid, {:convert, pdf_path, output_path})
  end

  def handle_call({:convert, pdf_path, output_path}, _from, state) do
    :ok = Ghostscript.convert(pdf_path, output_path)

    {:reply, :ok, state}
  end
end
