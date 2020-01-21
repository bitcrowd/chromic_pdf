defmodule ChromicPDF.Ghostscript do
  @moduledoc false

  require EEx

  @ghostscript_bin "gs"

  @pdfinfo_ps Path.expand("../../assets/pdfinfo.ps", __ENV__.file)
  @adobe_icc Path.expand("../../assets/AdobeRGB1998.icc", __ENV__.file)
  @psdef_ps Path.expand("../../assets/psdef.ps.eex", __ENV__.file)

  @external_resource @psdef_ps

  @pdfinfo_keys %{
    "__knowninfoTitle" => :title,
    "__knowninfoAuthor" => :author,
    "__knowninfoSubject" => :subject,
    "__knowninfoKeywords" => :keywords,
    "__knowninfoCreator" => :creator,
    "__knowninfoProducer" => :producer,
    "__knowninfoCreationDate" => :creation_date,
    "__knowninfoModDate" => :mod_date,
    "__knowninfoTrapped" => :trapped
  }

  EEx.function_from_file(:def, :render_psdef_ps, @psdef_ps, [:assigns])

  def convert(pdf_path, output_path) do
    pdf_path = Path.expand(pdf_path)

    psdef_path = create_psdef_ps(pdf_path)

    pdf_path
    |> embed_fonts()
    |> convert_to_pdfa2(psdef_path, output_path)
  end

  defp create_psdef_ps(pdf_path) do
    output_path = Path.expand("../#{Path.basename(pdf_path)}-psdef.ps", pdf_path)

    rendered =
      pdf_path
      |> pdfinfo()
      |> Map.put(:adobe_icc, @adobe_icc)
      |> render_psdef_ps()

    File.write!(output_path, rendered)

    output_path
  end

  defp embed_fonts(pdf_path) do
    output_path = Path.expand("../#{Path.basename(pdf_path)}-fonts-embedded.pdf", pdf_path)

    system_cmd!(
      @ghostscript_bin,
      [
        "-dQUIET",
        "-sstdout=/dev/null",
        "-dBATCH",
        "-dNOPAUSE",
        "-dNOOUTERSAVE",
        "-dCompatibilityLevel=1.4",
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
      ]
    )

    output_path
  end

  defp convert_to_pdfa2(pdf_path, psdef_path, output_path) do
    system_cmd!(
      @ghostscript_bin,
      [
        "-dQUIET",
        "-sstdout=/dev/null",
        "-dPDFA=2",
        "-dBATCH",
        "-dNOPAUSE",
        "-dNOOUTERSAVE",
        "-dCompatibilityLevel=1.4",
        "-dPDFACompatibilityPolicy=1",
        "-sProcessColorModel=DeviceRGB",
        "-sColorConversionStrategy=RGB",
        ~s(-sOutputICCProfile="#{@adobe_icc}"),
        "-sDEVICE=pdfwrite",
        ~s(-sOutputFile="#{output_path}"),
        ~s("#{pdf_path}"),
        ~s("#{psdef_path}")
      ]
    )

    :ok
  end

  defp pdfinfo(pdf_path) do
    infos_from_file = extract_info_from_file(pdf_path)

    @pdfinfo_keys
    |> Enum.map(fn {ext, int} -> {int, Map.get(infos_from_file, ext, "")} end)
    |> Enum.into(%{})
  end

  defp extract_info_from_file(pdf_path) do
    {output, 0} =
      System.cmd(
        @ghostscript_bin,
        ["-dNODISPLAY", "-q", ~s(-sFile="#{pdf_path}"), @pdfinfo_ps]
      )

    output
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(&parse_info_line/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
    |> Map.update("__knowninfoTrapped", "", &fix_info_trapped/1)
  end

  defp parse_info_line(line) do
    if String.contains?(line, ": ") do
      [key, value] = String.split(line, ": ", parts: 2)

      if Map.has_key?(@pdfinfo_keys, key) do
        {key, value}
      end
    end
  end

  defp fix_info_trapped(value) do
    case String.downcase(value) do
      "/true" -> "/True"
      "/false" -> "/False"
      _ -> ""
    end
  end

  defp system_cmd!(bin, args) do
    {_output, 0} = System.cmd(bin, args, stderr_to_stdout: true)
  end
end
