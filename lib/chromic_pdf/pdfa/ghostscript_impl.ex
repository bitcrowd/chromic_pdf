defmodule ChromicPDF.GhostscriptImpl do
  @moduledoc false

  import ChromicPDF.Utils, only: [system_cmd!: 3]

  @behaviour ChromicPDF.Ghostscript

  @impl ChromicPDF.Ghostscript
  def run_postscript(pdf_path, ps_path) do
    {output, 0} =
      System.cmd(
        ghostscript_executable(),
        ["-dNODISPLAY", "-q", ~s(-sFile="#{pdf_path}"), ps_path]
      )

    output
  end

  @impl ChromicPDF.Ghostscript
  def embed_fonts(pdf_path, output_path) do
    ghostscript_cmd!([
      "-dEmbedAllFonts=true",
      "-dSubsetFonts=true",
      "-dCompressFonts=true",
      "-dCompressPages=true",
      "-sColorConversionStrategy=RGB",
      "-dDownsampleMonoImages=false",
      "-dDownsampleGrayImages=false",
      "-dDownsampleColorImages=false",
      "-dAutoFilterColorImages=false",
      "-dAutoFilterGrayImages=false",
      "-sDEVICE=pdfwrite",
      ~s(-sOutputFile="#{output_path}"),
      ~s("#{pdf_path}")
    ])

    :ok
  end

  @impl ChromicPDF.Ghostscript
  def convert_to_pdfa(pdf_path, pdfa_version, icc_path, pdfa_def_ps_path, output_path)
      when pdfa_version in ["2", "3"] do
    ghostscript_cmd!([
      "-dPDFA=#{pdfa_version}",
      # http://git.ghostscript.com/?p=ghostpdl.git;a=commitdiff;h=094d5a1880f1cb9ed320ca9353eb69436e09b594
      "-dPDFACompatibilityPolicy=1",
      "-sProcessColorModel=DeviceRGB",
      "-sColorConversionStrategy=RGB",
      ~s(-sOutputICCProfile="#{icc_path}"),
      "-sDEVICE=pdfwrite",
      ~s(-sOutputFile="#{output_path}"),
      ~s("#{pdf_path}"),
      ~s("#{pdfa_def_ps_path}")
    ])

    :ok
  end

  @default_args [
    "-dQUIET",
    "-sstdout=/dev/null",
    "-dBATCH",
    "-dNOPAUSE",
    "-dNOOUTERSAVE",
    "-dCompatibilityLevel=1.4"
  ]

  defp ghostscript_cmd!(args) do
    system_cmd!(ghostscript_executable(), @default_args ++ args, stderr_to_stdout: true)
  end

  @ghostscript_bin "gs"

  defp ghostscript_executable do
    System.find_executable(@ghostscript_bin) || raise("could not find ghostscript")
  end
end
