# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.TestAPI do
  @moduledoc false

  import ExUnit.Assertions
  import ChromicPDF.Utils, only: [system_cmd!: 2, with_tmp_dir: 1]

  @test_html Path.expand("../../fixtures/test.html", __ENV__.file)
  @test_dynamic_html Path.expand("../../fixtures/test_dynamic.html", __ENV__.file)
  @test_exception_html Path.expand("../../fixtures/test_exception.html", __ENV__.file)
  @test_image Path.expand("../../fixtures/image_with_text.svg", __ENV__.file)

  @output Path.expand("../../test.pdf", __ENV__.file)

  def test_html_path, do: @test_html
  def test_html, do: File.read!(test_html_path())

  def test_dynamic_html_path, do: @test_dynamic_html
  def test_dynamic_html, do: File.read!(test_dynamic_html_path())

  defp test_exception_html_path, do: @test_exception_html
  def test_exception_html, do: File.read!(test_exception_html_path())

  def test_image_path, do: @test_image

  def print_to_pdf do
    print_to_pdf(fn _output -> :ok end)
  end

  def print_to_pdf(cb) when is_function(cb) do
    print_to_pdf({:url, "file://#{@test_html}"}, [], cb)
  end

  def print_to_pdf(input) when is_tuple(input) or is_map(input) do
    print_to_pdf(input, [], fn _output -> :ok end)
  end

  def print_to_pdf(params) when is_list(params) do
    print_to_pdf({:url, "file://#{@test_html}"}, params, fn _output -> :ok end)
  end

  def print_to_pdf(params, cb) when is_list(params) and is_function(cb) do
    print_to_pdf({:url, "file://#{@test_html}"}, params, cb)
  end

  def print_to_pdf(input, cb) when (is_tuple(input) or is_map(input)) and is_function(cb) do
    print_to_pdf(input, [], cb)
  end

  def print_to_pdf(input, params) when (is_tuple(input) or is_map(input)) and is_list(params) do
    print_to_pdf(input, params, fn _output -> :ok end)
  end

  def print_to_pdf(input, pdf_params, cb) do
    with_output_path(fn output ->
      assert ChromicPDF.print_to_pdf(input, Keyword.put(pdf_params, :output, output)) == :ok
      assert File.exists?(output)

      text = system_cmd!("pdftotext", [output, "-"])

      case Function.info(cb, :arity) do
        {:arity, 1} ->
          cb.(text)

        {:arity, 2} ->
          info = system_cmd!("pdfinfo", [output])
          cb.(text, info)
      end
    end)
  end

  def print_to_pdf_delayed(delay_ms) do
    print_to_pdf(
      evaluate: %{
        expression: """
        window.setTimeout(function() {
          document.getElementById('print-ready').setAttribute('ready-to-print', '');
        }, #{delay_ms});
        """
      },
      wait_for: %{selector: "#print-ready", attribute: "ready-to-print"}
    )
  end

  def with_output_path(fun) do
    fun.(@output)
  after
    File.rm_rf!(@output)
  end

  def capture_screenshot(opts \\ []) do
    {source, opts} = Keyword.pop(opts, :source)

    ChromicPDF.capture_screenshot(source || {:url, "file://#{@test_html}"}, opts)
  end

  def capture_screenshot_and_identify(opts) do
    with_tmp_dir(fn tmp_dir ->
      img = "#{tmp_dir}/test"
      :ok = capture_screenshot([{:output, img} | opts])

      {stdout, 0} = System.cmd("identify", [img])

      [_, format, dimensions | _] = String.split(stdout, " ")

      %{"width" => width, "height" => height} =
        Regex.named_captures(~r/^(?<width>\d+)x(?<height>\d+)$/, dimensions)

      {format, String.to_integer(width), String.to_integer(height)}
    end)
  end
end
