defmodule ChromicPDF.PrintToPDFAsStream do
  @moduledoc false

  import ChromicPDF.ProtocolMacros

  steps do
    include_protocol(ChromicPDF.Navigate)

    call(:print_to_pdf, "Page.printToPDF", &print_to_pdf_opts/1, %{})
    await_response(:printed, ["stream"])

    include_protocol(ChromicPDF.ResetTarget)

    output("stream")
  end

  defp print_to_pdf_opts(params) do
    params
    |> Map.get(:print_to_pdf, %{})
    |> Map.put(:transferMode, "ReturnAsStream")
  end
end
