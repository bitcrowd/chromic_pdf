defmodule ChromicPDF.PrintToPDF do
  @moduledoc false

  import ChromicPDF.ProtocolMacros

  steps do
    include_protocol(ChromicPDF.Navigate)

    call(:print_to_pdf, "Page.printToPDF", &print_to_pdf_opts/1, %{})

    if_option {:stream, true} do
      await_response(:print_started, ["stream"])
      include_protocol(ChromicPDF.ReadStream)
    end

    if_option {:stream, false} do
      await_response(:printed, ["data"])
    end

    include_protocol(ChromicPDF.ResetTarget)
    output("data")
  end

  defp print_to_pdf_opts(params) do
    params
    |> Map.get(:print_to_pdf, %{})
    |> Map.put(:transferMode, transfer_mode(params))
  end

  defp transfer_mode(params) do
    if Map.get(params, :stream, false) do
      "ReturnAsStream"
    else
      "ReturnAsBase64"
    end
  end
end
