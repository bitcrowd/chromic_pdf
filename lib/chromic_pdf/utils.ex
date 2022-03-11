defmodule ChromicPDF.Utils do
  @moduledoc false

  @dev_pool_size Application.compile_env(:chromic_pdf, :dev_pool_size)
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
      |> Enum.map_join(&pad_two_digits/1)

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

  @spec find_supervisor_child(pid() | atom(), module()) :: pid()
  def find_supervisor_child(supervisor, module) when is_atom(supervisor) do
    supervisor
    |> Process.whereis()
    |> find_supervisor_child(module)
  end

  def find_supervisor_child(supervisor, module) when is_pid(supervisor) do
    supervisor
    |> Supervisor.which_children()
    |> Enum.find(fn {mod, _, _, _} -> mod == module end)
    |> elem(1)
  end

  @spec priv_asset(binary()) :: binary()
  def priv_asset(filename) do
    Path.join([Application.app_dir(:chromic_pdf), "priv", filename])
  end

  @spec default_pool_size() :: non_neg_integer()

  if @dev_pool_size do
    def default_pool_size, do: @dev_pool_size
  else
    def default_pool_size, do: max(div(System.schedulers_online(), 2), 1)
  end
end
