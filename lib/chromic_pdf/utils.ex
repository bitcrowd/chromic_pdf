# SPDX-License-Identifier: Apache-2.0

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

  @spec system_cmd!(binary(), [binary()]) :: binary()
  @spec system_cmd!(binary(), [binary()], keyword()) :: binary()
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

  @spec find_supervisor_child!(pid() | atom(), module()) :: pid() | no_return()
  def find_supervisor_child!(supervisor, module) when is_atom(supervisor) or is_pid(supervisor) do
    find_supervisor_child(supervisor, module) ||
      raise("can't find #{module} child of supervisor #{inspect(supervisor)}")
  end

  @spec find_supervisor_child(pid() | atom(), module()) :: pid() | nil
  def find_supervisor_child(supervisor, module) do
    supervisor
    |> supervisor_children(module)
    |> case do
      [] -> nil
      [{_id, pid}] -> pid
    end
  end

  @spec supervisor_children(pid() | atom(), module()) :: [{term(), pid()}]
  def supervisor_children(supervisor, module) when is_atom(supervisor) do
    supervisor
    |> Process.whereis()
    |> supervisor_children(module)
  end

  def supervisor_children(supervisor, module) when is_pid(supervisor) do
    supervisor
    |> Supervisor.which_children()
    |> Enum.filter(fn {_, _, _, [mod | _]} -> mod == module end)
    |> Enum.map(fn {id, pid, _, _} -> {id, pid} end)
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

  @spec rendered_to_binary(iodata | tuple | struct) :: binary
  def rendered_to_binary(rendered) do
    rendered
    |> rendered_to_iodata()
    |> :erlang.iolist_to_binary()
  end

  @spec rendered_to_iodata(iodata | tuple | struct) :: iodata
  def rendered_to_iodata(value) when is_binary(value) or is_list(value), do: value

  if Code.ensure_loaded?(Phoenix.HTML.Safe) do
    # credo:disable-for-next-line Credo.Check.Design.AliasUsage
    def rendered_to_iodata(value), do: Phoenix.HTML.Safe.to_iodata(value)
  end

  @spec with_app_config_cache(atom, function) :: any
  def with_app_config_cache(key, function) do
    case Application.get_env(:chromic_pdf, key) do
      nil ->
        result = function.()
        Application.put_env(:chromic_pdf, key, result)
        result

      value ->
        value
    end
  end

  @spec semver_compare(binary, list) :: :lt | :eq | :gt
  def semver_compare(x, y) do
    x
    |> String.trim()
    |> String.split(".")
    |> Enum.map(&String.to_integer/1)
    |> Enum.zip(y)
    |> do_semver_compare()
  end

  defp do_semver_compare([]), do: :eq
  defp do_semver_compare([{x, y} | _rest]) when x < y, do: :lt
  defp do_semver_compare([{x, y} | _rest]) when x > y, do: :gt
  defp do_semver_compare([{x, y} | rest]) when x == y, do: do_semver_compare(rest)
end
