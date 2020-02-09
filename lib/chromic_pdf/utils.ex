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

  @spec to_postscript_date(DateTime.t()) :: binary()
  def to_postscript_date(%DateTime{} = value) do
    date =
      [:year, :month, :day, :hour, :minute, :second]
      |> Enum.map(&Map.fetch!(value, &1))
      |> Enum.map(&pad_two_digits/1)
      |> Enum.join()

    "D:#{date}+#{pad_two_digits(value.utc_offset)}'00'"
  end

  defp pad_two_digits(i) do
    String.pad_leading(to_string(i), 2, "0")
  end

  def system_cmd!(cmd, args, opts \\ []) do
    case System.cmd(cmd, args, opts) do
      {output, 0} ->
        output

      {output, exit_status} ->
        raise("""
          #{cmd} exited with status #{exit_status}!

        #{output}
        """)
    end
  end
end
