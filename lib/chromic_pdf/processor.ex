defmodule ChromicPDF.Processor do
  @moduledoc false

  alias ChromicPDF.{GhostscriptPool, SessionPool}

  @type url :: binary()
  @type path :: binary()
  @type pdf_params :: map()
  @type pdfa_params :: keyword()
  @type output :: path() | (path() -> any())

  @spec print_to_pdf(atom(), url(), pdf_params(), output()) :: :ok
  def print_to_pdf(chromic, url, params, output)
      when is_atom(chromic) and is_binary(url) and is_map(params) and is_binary(output) do
    print_to_pdf(chromic, url, params, fn pdf_file ->
      File.cp!(pdf_file, output)
    end)
  end

  def print_to_pdf(chromic, url, params, output)
      when is_atom(chromic) and is_binary(url) and is_map(params) and is_function(output, 1) do
    with_tmp_files(".pdf", 1, fn [pdf_file] ->
      SessionPool.print_to_pdf(chromic, url, params, pdf_file)
      output.(pdf_file)
    end)
  end

  @spec convert_to_pdfa(atom(), path(), pdfa_params(), output()) :: :ok
  def convert_to_pdfa(chromic, pdf_file, params, output)
      when is_atom(chromic) and is_binary(pdf_file) and is_list(params) and is_binary(output) do
    convert_to_pdfa(chromic, pdf_file, params, fn pdfa_file ->
      File.cp!(pdfa_file, output)
    end)
  end

  def convert_to_pdfa(chromic, pdf_file, params, output)
      when is_atom(chromic) and is_binary(pdf_file) and is_list(params) and is_function(output, 1) do
    with_tmp_files(".pdf", 1, fn [pdfa_file, pdfa_file] ->
      GhostscriptPool.convert(chromic, pdf_file, params, pdfa_file)
      output.(pdfa_file)
    end)
  end

  @spec print_to_pdfa(atom(), url(), pdf_params(), pdfa_params(), output()) :: :ok
  def print_to_pdfa(chromic, url, pdf_params, pdfa_params, output)
      when is_atom(chromic) and is_binary(url) and is_map(pdf_params) and is_list(pdfa_params) and
             is_binary(output) do
    print_to_pdfa(chromic, url, pdf_params, pdfa_params, fn pdfa_file ->
      File.cp!(pdfa_file, output)
    end)
  end

  def print_to_pdfa(chromic, url, pdf_params, pdfa_params, output)
      when is_atom(chromic) and is_binary(url) and is_map(pdf_params) and is_list(pdfa_params) and
             is_function(output, 1) do
    with_tmp_files(".pdf", 2, fn [pdf_file, pdfa_file] ->
      SessionPool.print_to_pdf(chromic, url, pdf_params, pdf_file)
      GhostscriptPool.convert(chromic, pdf_file, pdfa_params, pdfa_file)
      output.(pdfa_file)
    end)
  end

  defp with_tmp_files(ext, n, cb) do
    with_tmp_dir(fn tmp_dir ->
      1..n
      |> Enum.map(fn _ -> Path.join(tmp_dir, random_file_name(ext)) end)
      |> cb.()
    end)
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
end
