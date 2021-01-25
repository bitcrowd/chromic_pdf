defmodule ChromicPDF.OnDemandTest do
  use ExUnit.Case, async: false
  import ChromicPDF.Assertions
  alias ChromicPDF.GetTargets

  test "on_demand is disabled by default" do
    assert_raise RuntimeError, ~r/ChromicPDF isn't running and no :on_demand config/, fn ->
      ChromicPDF.print_to_pdf({:html, ""})
    end
  end

  describe "when on_demand is false" do
    @pool_size 1

    setup do
      start_supervised({ChromicPDF, session_pool: [size: @pool_size]})
      :ok
    end

    test "Chrome is spawned eagerly" do
      targets_before =
        assert_eventually(&GetTargets.run/0, fn targets ->
          length(targets) == @pool_size
        end)

      assert_continuously(&GetTargets.run/0, fn targets_now ->
        assert targets_now == targets_before
      end)
    end
  end

  describe "when on_demand is true" do
    setup do
      start_supervised({ChromicPDF, on_demand: true})
      :ok
    end

    test "Chrome is spawned dynamically" do
      targets_before = GetTargets.run()
      refute GetTargets.run() == targets_before
      targets_before = GetTargets.run()
      refute GetTargets.run() == targets_before
      targets_before = GetTargets.run()
      refute GetTargets.run() == targets_before
    end
  end
end
