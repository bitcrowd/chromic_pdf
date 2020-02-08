defmodule ChromicPDF.Utils do
  @moduledoc false

  @chars String.codepoints("abcdefghijklmnopqrstuvwxyz0123456789")

  @spec random_file_name(binary()) :: binary()
  def random_file_name(ext \\ "") do
    @chars
    |> Enum.shuffle()
    |> Enum.take(12)
    |> Enum.join()
    |> Kernel.<>(ext)
  end

  @spec with_tmp_dir((binary() -> any())) :: any()
  def with_tmp_dir(cb) do
    path =
      Path.join(
        System.tmp_dir!(),
        random_file_name()
      )

    File.mkdir!(path)

    try do
      cb.(path)
    after
      File.rm_rf!(path)
    end
  end
end
