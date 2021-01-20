defmodule ChromicPDF.SessionRestartTest do
  use ExUnit.Case, async: false
  import ChromicPDF.Assertions
  alias ChromicPDF.GetTargets

  describe "sessions automatically restart after a number of operations" do
    setup do
      start_supervised!({ChromicPDF, max_session_uses: 2})
      :ok
    end

    test "session restart spawns a new session process" do
      targets_before = GetTargets.baseline()

      # After the first print operation, the targetIds should remain exactly the same.
      {:ok, _blob} = ChromicPDF.print_to_pdf({:html, ""})

      assert_continuously(&GetTargets.now/0, fn targets_now ->
        targets_now == targets_before
      end)

      # After the second print operation, we expect the Session to have restarted its target
      # process, so exactly one targetId should have changed.
      {:ok, _blob} = ChromicPDF.print_to_pdf({:html, ""})

      assert_eventually(&GetTargets.now/0, fn targets_now ->
        length(targets_before) == length(targets_now) &&
          length(targets_before -- targets_now) == 1 &&
          length(targets_now -- targets_before) == 1
      end)
    end
  end
end
