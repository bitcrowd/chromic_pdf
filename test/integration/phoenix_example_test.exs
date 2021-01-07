defmodule ChromicPDF.PhoenixExampleTest do
  use ExUnit.Case, async: false
  import ChromicPDF.Utils, only: [system_cmd!: 2]

  describe "phoenix example app" do
    setup do
      start_supervised!(ChromicPDF)
      :ok
    end

    @tag :pdftotext
    test "the example invoice template can be rendered" do
      PhoenixExample.InvoiceView.dummy(fn invoice_pdf ->
        assert system_cmd!("pdftotext", [invoice_pdf, "-"]) =~ "Invoice"
      end)
    end
  end
end
