defmodule ChromicPDF.GhostscriptWorker do
  @moduledoc false

  use GenServer
  require EEx
  import ChromicPDF.Utils

  @ghostscript Application.get_env(:chromic_pdf, :ghostscript, ChromicPDF.GhostscriptImpl)

  # ------------- API ----------------

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def convert(pid, pdf_path, params, output_path) do
    GenServer.call(pid, {:convert, pdf_path, params, output_path})
  end

  # --------- Implementation ---------

  @psdef_ps Path.expand("../PDFA_def.ps.eex", __ENV__.file)
  @external_resource @psdef_ps

  @pdfinfo_keys %{
    "__knowninfoTitle" => :title,
    "__knowninfoAuthor" => :author,
    "__knowninfoSubject" => :subject,
    "__knowninfoKeywords" => :keywords,
    "__knowninfoCreator" => :creator,
    "__knowninfoCreationDate" => :creation_date,
    "__knowninfoModDate" => :mod_date,
    "__knowninfoTrapped" => :trapped
  }

  EEx.function_from_file(:defp, :render_pdfa_def_ps, @psdef_ps, [:assigns])

  @impl GenServer
  def init(_) do
    {:ok, nil}
  end

  @impl GenServer
  def handle_call({:convert, pdf_path, params, output_path}, _from, state) do
    pdf_path = Path.expand(pdf_path)
    pdf_with_fonts = Path.join(Path.dirname(output_path), random_file_name(".pdf"))
    pdfa_def_ps_path = Path.join(Path.dirname(output_path), random_file_name(".ps"))

    create_pdfa_def_ps!(pdf_path, params, pdfa_def_ps_path)
    create_pdf_with_fonts!(pdf_path, pdf_with_fonts)
    convert_to_pdfa!(pdf_with_fonts, params, pdfa_def_ps_path, output_path)

    {:reply, :ok, state}
  end

  defp create_pdfa_def_ps!(pdf_path, params, pdfa_def_ps_path) do
    info = Keyword.get(params, :info, %{})
    pdfa_def_ext = Keyword.get(params, :pdfa_def_ext)

    rendered =
      pdf_path
      |> pdfinfo()
      |> Map.merge(info)
      |> Enum.into(%{}, &cast_info_value/1)
      |> Map.put(:eci_icc, priv_asset("eciRGB_v2.icc"))
      |> Map.put(:pdfa_def_ext, pdfa_def_ext)
      |> render_pdfa_def_ps()

    File.write!(pdfa_def_ps_path, rendered)
  end

  defp create_pdf_with_fonts!(pdf_path, pdf_with_fonts) do
    :ok = @ghostscript.embed_fonts(pdf_path, pdf_with_fonts)
  end

  defp convert_to_pdfa!(pdf_with_fonts, params, pdfa_def_ps_path, output_path) do
    pdfa_version =
      params
      |> Keyword.get(:pdfa_version, 3)
      |> to_string()

    :ok =
      @ghostscript.convert_to_pdfa(
        pdf_with_fonts,
        pdfa_version,
        priv_asset("eciRGB_v2.icc"),
        pdfa_def_ps_path,
        output_path
      )
  end

  defp pdfinfo(pdf_path) do
    infos_from_file =
      pdf_path
      |> @ghostscript.run_postscript(priv_asset("pdfinfo.ps"))
      |> String.trim()
      |> String.split("\n")
      |> Enum.map(&parse_info_line/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.into(%{})

    Enum.into(
      @pdfinfo_keys,
      %{},
      fn {ext, int} -> {int, Map.get(infos_from_file, ext, "")} end
    )
  end

  defp parse_info_line(line) do
    if String.contains?(line, ": ") do
      [key, value] = String.split(line, ": ", parts: 2)

      if Map.has_key?(@pdfinfo_keys, key) do
        {key, value}
      end
    end
  end

  defp cast_info_value({:trapped, value}) do
    cast =
      case String.downcase(value) do
        "/true" -> "/True"
        "/false" -> "/False"
        _ -> nil
      end

    {:trapped, cast}
  end

  defp cast_info_value({key, %DateTime{} = value}) do
    {key, to_postscript_date(value)}
  end

  defp cast_info_value(other), do: other

  defp priv_asset(filename) do
    Path.join([Application.app_dir(:chromic_pdf), "priv", filename])
  end
end
