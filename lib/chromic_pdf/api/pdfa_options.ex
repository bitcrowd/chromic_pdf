defmodule ChromicPDF.PDFAOptions do
  @moduledoc false

  def feed_ghostscript_file_into_output(pdfa_path, opts) do
    case Keyword.get(opts, :output) do
      path when is_binary(path) ->
        File.cp!(pdfa_path, path)
        :ok

      fun when is_function(fun, 1) ->
        {:ok, fun.(pdfa_path)}

      nil ->
        data =
          pdfa_path
          |> File.read!()
          |> Base.encode64()

        {:ok, data}
    end
  end
end
