defmodule ChromicPDF.PrintToPDF do
  @moduledoc false

  import ChromicPDF.ProtocolMacros

  steps do
    include_protocol(ChromicPDF.Navigate)

    call(:print_to_pdf, "Page.printToPDF", &Map.get(&1, :print_to_pdf, %{}), %{})
    await_response(:printed, ["data"])

    include_protocol(ChromicPDF.ResetTarget)

    output("data")
  end
end
