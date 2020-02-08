defmodule ChromicPDF.Processor do
  @moduledoc false

  alias ChromicPDF.{GhostscriptPool, SessionPool}

  @type url :: binary()
  @type path :: binary()
  @type pdf_input :: {:url, url()}
  @type pdf_params :: map()
  @type pdfa_input :: {:path, path()}
  @type pdfa_params :: keyword()
  @type output :: path() | (path() -> any())

  @type request :: %{
          required(:current) => pdf_input() | pdfa_input(),
          optional(:pdf_params) => pdf_params(),
          optional(:pdfa_params) => pdfa_params(),
          required(:output) => output()
        }

  defguardp is_url(url) when is_binary(url)
  defguardp is_path(path) when is_binary(path)
  defguardp is_pdf_params(params) when is_map(params)
  defguardp is_pdfa_params(params) when is_list(params)
  defguardp is_output(output) when is_binary(output) or is_function(output, 1)

  @spec from_url(url()) :: {:url, url()}
  def from_url(url) when is_url(url), do: {:url, url}

  @spec from_path(path()) :: {:path, path()}
  def from_path(path) when is_path(path), do: {:path, path}

  @spec print_to_pdf(pdf_input(), pdf_params(), output()) :: request()
  def print_to_pdf(pdf_input, pdf_params, output)
      when is_pdf_params(pdf_params) and is_output(output) do
    %{
      current: pdf_input,
      pdf_params: pdf_params,
      output: output
    }
  end

  @spec convert_to_pdfa(pdfa_input(), pdfa_params(), output()) :: request()
  def convert_to_pdfa(pdfa_input, pdfa_params, output)
      when is_pdfa_params(pdfa_params) and is_output(output) do
    %{
      current: pdfa_input,
      pdfa_params: pdfa_params,
      output: output
    }
  end

  @spec print_to_pdfa(pdf_input(), pdf_params(), pdfa_params(), output()) :: request()
  def print_to_pdfa(pdf_input, pdf_params, pdfa_params, output)
      when is_pdf_params(pdf_params) and is_pdfa_params(pdfa_params) and is_output(output) do
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

  defp with_tmp_dir(cb) do
    path =
      Path.join(
        System.tmp_dir!(),
        random_file_name()
      )

    File.mkdir!(path)

    try do
      cb.(path)
    after
      File.rm_rf!(path)
    end
  end

  @chars String.codepoints("abcdefghijklmnopqrstuvwxyz0123456789")
  defp random_file_name(ext \\ "") do
    @chars
    |> Enum.shuffle()
    |> Enum.take(12)
    |> Enum.join()
    |> Kernel.<>(ext)
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
