defmodule ChromicPDF.Ghostscript do
  @moduledoc false

  @callback run_postscript(pdf_path :: binary(), ps_path :: binary()) :: binary()
  @callback embed_fonts(pdf_path :: binary(), output :: binary()) :: :ok
  @callback convert_to_pdfa(
              pdf_path :: binary(),
              pdfa_version :: binary(),
              icc_path :: binary(),
              pdfa_def_ps_path :: binary(),
              output_path :: binary()
            ) :: :ok
end
