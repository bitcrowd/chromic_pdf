defmodule ChromicPDF.OSHelper do
  @moduledoc false

  @ps_cmd :"ps ax | grep -v grep | grep -i Chrom | grep type=renderer"

  # This gets all pids of Chrome, chromium*, chrome-browser, or whatever Chrome process on the
  # system that have a type=renderer argument, and reads their pids from "ps" output. Chrome
  # spawns 1 renderer per browser target (tab).
  # Please don't mess with the "ps ax" line above, ps's options are quite cumbersome to get right
  # in a platform-independent way.
  def chrome_renderer_pids do
    # Sleep for 0.5 seconds to allow Chrome initialization/termination to happen.
    :timer.sleep(500)

    @ps_cmd
    |> :os.cmd()
    |> to_string()
    |> String.trim()
    |> String.split("\n")
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn x -> Regex.named_captures(~r/[^\d]*(?<pid>[\d]+)/, x)["pid"] end)
  end
end
