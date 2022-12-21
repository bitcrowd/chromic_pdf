# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.GhostscriptImpl do
  @moduledoc false

  import ChromicPDF.Utils, only: [system_cmd!: 3]

  @behaviour ChromicPDF.Ghostscript

  @default_args [
    "-dQUIET",
    "-sstdout=/dev/null",
    "-dBATCH",
    "-dNOPAUSE",
    "-dNOOUTERSAVE",
    "-dCompatibilityLevel=1.4"
  ]

  @ghostscript_bin "gs"
  @ghostscript_safer_version [9, 28]
  @ghostscript_new_interpreter_version [9, 56]

  @impl ChromicPDF.Ghostscript
  def run_postscript(pdf_path, ps_path) do
    ghostscript_cmd!([
      ~s(--permit-file-read=#{pdf_path}),
      ~s(--permit-file-read=#{ps_path}),
      "-dNODISPLAY",
      "-q",
      ~s(-sFile=#{pdf_path}),
      ps_path
    ])
  end

  @impl ChromicPDF.Ghostscript
  def embed_fonts(pdf_path, output_path) do
    ghostscript_cmd!([
      ~s(--permit-file-read=#{pdf_path}),
      ~s(--permit-file-write=#{output_path}),
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
      ~s(-sOutputFile=#{output_path}),
      ~s(#{pdf_path})
    ])

    :ok
  end

  @impl ChromicPDF.Ghostscript
  def convert_to_pdfa(pdf_path, pdfa_version, icc_path, pdfa_def_ps_path, output_path)
      when pdfa_version in ["2", "3"] do
    ghostscript_cmd!([
      ~s(--permit-file-read=#{pdf_path}),
      ~s(--permit-file-read=#{icc_path}),
      ~s(--permit-file-read=#{pdfa_def_ps_path}),
      ~s(--permit-file-write=#{output_path}),
      "-dPDFA=#{pdfa_version}",
      # http://git.ghostscript.com/?p=ghostpdl.git;a=commitdiff;h=094d5a1880f1cb9ed320ca9353eb69436e09b594
      "-dPDFACompatibilityPolicy=1",
      "-sProcessColorModel=DeviceRGB",
      "-sColorConversionStrategy=RGB",
      ~s(-sOutputICCProfile=#{icc_path}),
      "-sDEVICE=pdfwrite",
      ~s(-sOutputFile=#{output_path}),
      ~s(#{pdf_path}),
      ~s(#{pdfa_def_ps_path})
    ])

    :ok
  end

  @impl ChromicPDF.Ghostscript
  def merge(pdf_path_list, output_path) do
    ghostscript_cmd!(
      ["-dNOPAUSE", "-sDEVICE=pdfwrite", "-sOUTPUTFILE=#{output_path}", "-dBATCH"] ++
        pdf_path_list
    )

    :ok
  end

  defp ghostscript_cmd!(args) do
    args =
      args
      |> maybe_strip_permit_flag()
      |> maybe_use_old_interpreter()

    system_cmd!(ghostscript_executable(), @default_args ++ args, stderr_to_stdout: true)
  end

  defp maybe_strip_permit_flag(args) do
    if ghostscript_version() < @ghostscript_safer_version do
      Enum.reject(args, &String.contains?(&1, "--permit"))
    else
      args
    end
  end

  defp maybe_use_old_interpreter(args) do
    if ghostscript_version() >= @ghostscript_new_interpreter_version do
      # We get segmentation faults with the new intepreter (see https://github.com/bitcrowd/chromic_pdf/issues/153):
      #
      # /usr/bin/gs exited with status 139!
      #
      # Ghostscript provides us with a workaround until they iron out all the issues:
      #
      # > In this (9.56.0) release, the new PDF interpreter is now ENABLED by default in Ghostscript,
      # > but the old PDF interpreter can be used as a fallback by specifying -dNEWPDF=false. We've
      # > provided this so users that encounter issues with the new interpreter can keep working while
      # > we iron out those issues, the option will not be available in the long term.
      ["-dNEWPDF=false" | args]
    else
      args
    end
  end

  defp ghostscript_executable do
    System.find_executable(@ghostscript_bin) || raise("could not find ghostscript")
  end

  defp ghostscript_version do
    case Application.get_env(:chromic_pdf, :ghostscript_version) do
      nil ->
        gsv = read_ghostscript_version()
        Application.put_env(:chromic_pdf, :ghostscript_version, gsv)
        gsv

      gsv ->
        gsv
    end
  end

  defp read_ghostscript_version do
    output = system_cmd!(ghostscript_executable(), ["-v"], stderr_to_stdout: true)
    captures = Regex.named_captures(~r/GPL Ghostscript (?<major>\d+)\.(?<minor>\d+)/, output)

    case captures do
      %{"major" => major, "minor" => minor} ->
        [String.to_integer(major), String.to_integer(minor)]

      nil ->
        raise("""
        Failed to determine Ghostscript version number!

        Output was:

        #{output}
        """)
    end
  end
end
