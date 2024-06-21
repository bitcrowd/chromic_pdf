# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.GhostscriptRunner do
  @moduledoc false

  import ChromicPDF.Utils, only: [semver_compare: 2, system_cmd!: 3, with_app_config_cache: 2]

  @default_args [
    "-sstdout=/dev/null",
    "-dQUIET",
    "-dBATCH",
    "-dNOPAUSE",
    "-dNOOUTERSAVE"
  ]

  @pdfwrite_default_args [
    "-sDEVICE=pdfwrite",
    "-dEmbedAllFonts=true",
    "-dSubsetFonts=true",
    "-dCompressFonts=true",
    "-dCompressPages=true",
    "-dDownsampleMonoImages=false",
    "-dDownsampleGrayImages=false",
    "-dDownsampleColorImages=false",
    "-dAutoFilterColorImages=false",
    "-dAutoFilterGrayImages=false"
  ]

  @ghostscript_bin "gs"
  @ghostscript_safer_version [9, 28]
  @ghostscript_new_interpreter_version {[9, 56], [10, 2]}

  @spec run_postscript(binary(), binary()) :: binary()
  def run_postscript(pdf_path, ps_path) do
    ghostscript_cmd!(%{
      read: [pdf_path, ps_path],
      write: [],
      args: [
        @default_args,
        "-dNODISPLAY",
        "-q",
        "-sFile=#{pdf_path}",
        ps_path
      ]
    })
  end

  @spec pdfwrite([binary()], binary()) :: :ok
  @spec pdfwrite([binary()], binary(), keyword()) :: :ok
  def pdfwrite(source_paths, output_path, opts \\ []) do
    %{
      read: source_paths,
      write: [output_path],
      args: [
        @default_args,
        @pdfwrite_default_args,
        "-sOutputFile=#{output_path}",
        source_paths
      ]
    }
    |> maybe_add_compatibility_level(opts)
    |> maybe_add_pdfa_args(opts)
    |> add_user_permit_reads(opts)
    |> ghostscript_cmd!()

    :ok
  end

  defp maybe_add_compatibility_level(command, opts) do
    if compatibility_level = Keyword.get(opts, :compatibility_level) do
      %{command | args: ["-dCompatibilityLevel=#{compatibility_level}" | command.args]}
    else
      command
    end
  end

  defp maybe_add_pdfa_args(command, opts) do
    if pdfa_opts = Keyword.get(opts, :pdfa) do
      version = Keyword.fetch!(pdfa_opts, :version)
      icc_path = Keyword.fetch!(pdfa_opts, :icc_path)

      args = [
        "-sOutputICCProfile=#{icc_path}",
        "-sProcessColorModel=DeviceRGB",
        "-sColorConversionStrategy=RGB",
        "-dPDFA=#{version}",
        # http://git.ghostscript.com/?p=ghostpdl.git;a=commitdiff;h=094d5a1880f1cb9ed320ca9353eb69436e09b594
        "-dPDFACompatibilityPolicy=1"
      ]

      %{command | read: [icc_path | command.read], args: args ++ command.args}
    else
      command
    end
  end

  defp add_user_permit_reads(command, opts) do
    values = Keyword.get(opts, :permit_read, [])

    %{command | read: values ++ command.read}
  end

  defp ghostscript_cmd!(command) do
    args =
      List.flatten([
        maybe_safer_args(command),
        maybe_disable_new_interpreter(),
        command.args
      ])

    system_cmd!(ghostscript_executable(), args, [])
  end

  defp maybe_safer_args(command) do
    if semver_compare(ghostscript_version(), @ghostscript_safer_version) in [:eq, :gt] do
      [
        "-dSAFER",
        Enum.map(command.read, &"--permit-file-read=#{&1}"),
        Enum.map(command.write, &"--permit-file-write=#{&1}")
      ]
    else
      []
    end
  end

  defp maybe_disable_new_interpreter do
    {bad, good} = @ghostscript_new_interpreter_version

    if semver_compare(ghostscript_version(), bad) in [:eq, :gt] &&
         semver_compare(ghostscript_version(), good) == :lt do
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
      ["-dNEWPDF=false"]
    else
      []
    end
  end

  defp ghostscript_executable do
    System.find_executable(@ghostscript_bin) || raise("could not find ghostscript")
  end

  defp ghostscript_version do
    with_app_config_cache(:ghostscript_version, &do_ghostscript_version/0)
  end

  defp do_ghostscript_version do
    output = system_cmd!(ghostscript_executable(), ["-v"], stderr_to_stdout: true)
    [version] = Regex.run(~r/\d+\.\d+/, output)
    version
  rescue
    e ->
      reraise(
        """
        Failed to determine Ghostscript version number! (#{e.__struct__})

        --- original exception --

        #{Exception.format(:error, e, __STACKTRACE__)}
        """,
        __STACKTRACE__
      )
  end
end
