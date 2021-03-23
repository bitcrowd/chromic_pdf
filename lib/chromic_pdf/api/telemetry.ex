defmodule ChromicPDF.Telemetry do
  @moduledoc false

  def with_telemetry(operation, opts, fun) do
    metadata = Keyword.get(opts, :telemetry_metadata, %{})

    :telemetry.span([:chromic_pdf, operation], metadata, fn ->
      {fun.(), metadata}
    end)
  end
end
