# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.OutputOptions do
  @moduledoc false

  import ChromicPDF.Utils
  alias ChromicPDF.ChromeError

  def feed_file_into_output(pdf_path, opts) do
    case Keyword.get(opts, :output) do
      path when is_binary(path) ->
        File.cp!(pdf_path, path)
        :ok

      fun when is_function(fun, 1) ->
        {:ok, fun.(pdf_path)}

      nil ->
        data =
          pdf_path
          |> File.read!()
          |> Base.encode64()

        {:ok, data}
    end
  end

  def feed_chrome_data_into_output({:error, error}, opts) do
    raise ChromeError, error: error, opts: opts
  end

  def feed_chrome_data_into_output({:ok, data}, opts) do
    case Keyword.get(opts, :output) do
      path when is_binary(path) ->
        File.write!(path, Base.decode64!(data))
        :ok

      fun when is_function(fun, 1) ->
        result_from_callback =
          with_tmp_dir(fn tmp_dir ->
            path = Path.join(tmp_dir, random_file_name(".pdf"))
            File.write!(path, Base.decode64!(data))
            fun.(path)
          end)

        {:ok, result_from_callback}

      nil ->
        {:ok, data}
    end
  end
end
