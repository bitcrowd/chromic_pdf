defmodule ChromicPDF.SessionRestartTest do
  use ExUnit.Case, async: false
  import ChromicPDF.OSHelper

  describe "sessions automatically restart after a number of operations" do
    setup do
      start_supervised!({ChromicPDF, max_session_uses: 2})
      :ok
    end

    test "session restart spawns a new session process" do
      pids_before = chrome_renderer_pids()

      {:ok, _blob} = ChromicPDF.print_to_pdf({:html, ""})

      # After the first print operation, the pids should remain exactly the same.
      pids_now = chrome_renderer_pids()
      assert pids_now == pids_before

      {:ok, _blob} = ChromicPDF.print_to_pdf({:html, ""})

      # After the second print operation, we expect the Session to have restarted its target
      # process, so exactly one pid should have changed.
      pids_now = chrome_renderer_pids()
      assert length(pids_before) == length(pids_now)
      assert assert(length(pids_before -- pids_now)) == 1
      assert assert(length(pids_now -- pids_before)) == 1
    end
  end
end
