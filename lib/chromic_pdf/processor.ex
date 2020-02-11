defmodule ChromicPDF.Processor do
  @moduledoc false

  import ChromicPDF.Utils
  alias ChromicPDF.{GhostscriptPool, SessionPool}

  @type url :: binary()
  @type path :: binary()

  @type pdf_input :: {:url, url()} | {:html, binary()}
  @type pdf_param :: {:print_to_pdf, map()}
  @type pdf_params :: [pdf_param()]

  @type pdfa_input :: {:path, path()}
  @type pdfa_param :: {:pdfa_version, binary()} | {:pdfa_def_ext, binary()} | {:info, map()}
  @type pdfa_params :: [pdfa_param()]
  @type output :: path() | (path() -> any())

  @type request :: %{
          required(:current) => pdf_input() | pdfa_input(),
          optional(:pdf_params) => pdf_params(),
          optional(:pdfa_params) => pdfa_params(),
          required(:output) => output()
        }

  defguardp is_path(path) when is_binary(path)
  defguardp is_pdf_params(params) when is_list(params)
  defguardp is_pdfa_params(params) when is_list(params)
  defguardp is_output(output) when is_binary(output) or is_function(output, 1)

  @spec print_to_pdf(pdf_input(), pdf_params(), output()) :: request()
  def print_to_pdf(pdf_input, pdf_params, output)
      when tuple_size(pdf_input) == 2 and is_pdf_params(pdf_params) and is_output(output) do
    %{
      current: pdf_input,
      pdf_params: pdf_params,
      output: output
    }
  end

  @spec convert_to_pdfa(pdfa_input(), pdfa_params(), output()) :: request()
  def convert_to_pdfa(pdfa_input, pdfa_params, output)
      when tuple_size(pdfa_input) == 2 and is_pdfa_params(pdfa_params) and is_output(output) do
    %{
      current: pdfa_input,
      pdfa_params: pdfa_params,
      output: output
    }
  end

  @spec print_to_pdfa(pdf_input(), pdf_params(), pdfa_params(), output()) :: request()
  def print_to_pdfa(pdf_input, pdf_params, pdfa_params, output)
      when tuple_size(pdf_input) == 2 and is_pdf_params(pdf_params) and
             is_pdfa_params(pdfa_params) and is_output(output) do
    %{
      current: pdf_input,
      pdf_params: pdf_params,
      pdfa_params: pdfa_params,
      output: output
    }
  end

  @spec run(request(), atom()) :: :ok
  def run(request, chromic) do
    with_tmp_dir(fn tmp_dir ->
      Enum.reduce(
        [
          &step_persist_html/3,
          &step_print_to_pdf/3,
          &step_convert_to_pdfa/3,
          &step_output/3
        ],
        request,
        fn step, state ->
          step.(state, chromic, tmp_dir)
        end
      )
    end)

    :ok
  end

  defp step_persist_html(%{current: {:html, html}} = request, _chromic, tmp_dir) do
    html_file = Path.join(tmp_dir, random_file_name(".html"))
    File.write!(html_file, html)

    %{request | current: {:url, "file://#{html_file}"}}
  end

  defp step_persist_html(request, _chromic, _tmp_dir) do
    request
  end

  defp step_print_to_pdf(
         %{current: {:url, url}, pdf_params: pdf_params} = request,
         chromic,
         tmp_dir
       )
       when not is_nil(pdf_params) do
    pdf_file = Path.join(tmp_dir, random_file_name(".pdf"))
    SessionPool.print_to_pdf(chromic, url, pdf_params, pdf_file)

    %{request | current: {:path, pdf_file}}
  end

  defp step_print_to_pdf(request, _chromic, _tmp_dir) do
    request
  end

  defp step_convert_to_pdfa(
         %{current: {:path, pdf_file}, pdfa_params: pdfa_params} = request,
         chromic,
         tmp_dir
       )
       when not is_nil(pdfa_params) do
    pdfa_file = Path.join(tmp_dir, random_file_name(".pdf"))
    GhostscriptPool.convert(chromic, pdf_file, pdfa_params, pdfa_file)

    %{request | current: {:path, pdfa_file}}
  end

  defp step_convert_to_pdfa(request, _chromic, _tmp_dir) do
    request
  end

  defp step_output(%{current: {:path, path}, output: output}, _chromic, _tmp_dir)
       when is_function(output, 1) do
    output.(path)
  end

  defp step_output(%{current: {:path, path}, output: output}, _chromic, _tmp_dir)
       when is_path(output) do
    File.cp!(path, output)
  end
end
