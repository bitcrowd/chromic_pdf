defmodule ChromicPDF.OnDemandTest do
  use ExUnit.Case, async: false
  import ChromicPDF.OSHelper

  test "on_demand is disabled by default" do
    assert_raise RuntimeError, ~r/ChromicPDF isn't running and no :on_demand config/, fn ->
      ChromicPDF.print_to_pdf({:html, ""})
    end
  end

  test "Chrome is spawned eagerly when on_demand is false" do
    pids_before = chrome_renderer_pids()

    {:ok, _pid} = start_supervised({ChromicPDF, session_pool: [size: 1]})

    pids_now = chrome_renderer_pids()
    assert length(pids_now) - length(pids_before) == 1
  end

  test "Chrome is spawned dynamically when on_demand is true" do
    pids_before = chrome_renderer_pids()

    {:ok, _pid} = start_supervised({ChromicPDF, on_demand: true})

    pids_now = chrome_renderer_pids()
    assert length(pids_now) == length(pids_before)

    {:ok, _blob} = ChromicPDF.print_to_pdf({:html, ""})

    pids_now = chrome_renderer_pids()
    assert length(pids_now) == length(pids_before)
  end
end
