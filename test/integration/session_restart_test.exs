defmodule ChromicPDF.SessionRestartTest do
  use ExUnit.Case, async: false

  @ps_cmd :"ps ax | grep -v grep | grep -i Chrom"
  @wait_ms 500

  # This gets all pids of Chrome, chromium*, chrome-browser, or whatever Chrome process on the
  # system and reads their pids from "ps" output. Please don't mess with the "ps ax" line above,
  # ps's options are quite cumbersome to get right in a platform-independent way.
  defp chrome_pids do
    @ps_cmd
    |> :os.cmd()
    |> to_string()
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(fn x -> Regex.named_captures(~r/[^\d]*(?<pid>[\d]+)/, x)["pid"] end)
  end

  defp print_and_wait do
    {:ok, _blob} = ChromicPDF.print_to_pdf({:html, ""})
    :timer.sleep(@wait_ms)
  end

  describe "sessions automatically restart after a number of operations" do
    setup do
      start_supervised!({ChromicPDF, max_session_uses: 2})
      :timer.sleep(@wait_ms)
      :ok
    end

    test "session restart spawns a new session process" do
      pids0 = chrome_pids()

      # We have at least 1 BEAM process, 1 Chrome process, and one target process.
      assert length(pids0) >= 3

      print_and_wait()
      pids1 = chrome_pids()

      # After the first print operation, the pids should remain exactly the same.
      assert pids0 == pids1

      print_and_wait()
      pids2 = chrome_pids()

      # After the second print operation, we expect the Session to have restarted its target
      # process, so exactly one pid should have changed.
      assert length(pids1) == length(pids2)
      assert assert(length(pids1 -- pids2)) == 1
      assert assert(length(pids2 -- pids1)) == 1
    end
  end
end
