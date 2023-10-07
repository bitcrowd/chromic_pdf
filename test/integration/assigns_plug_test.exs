# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.AssignsPlugTest do
  use ExUnit.Case, async: false
  import ChromicPDF.TestAPI
  alias ChromicPDF.TestServer

  describe "Assigns passing via ChromicPDF.AssignsPlug" do
    setup do
      start_supervised!(ChromicPDF)
      start_supervised!(TestServer.bandit(:http))

      %{port: TestServer.port(:http)}
    end

    @tag :pdftotext
    test "assigns can be passed via :assigns option for :url source", %{port: port} do
      source = {:url, "http://localhost:#{port}/with_plug"}

      print_to_pdf(source, [assigns: %{hello: "world"}], fn text ->
        assert String.contains?(text, ~s(%{hello: "world"}))
      end)
    end
  end
end
