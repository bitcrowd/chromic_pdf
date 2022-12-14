defmodule Benchmark1 do
  def run do
    # Kills all Chrome instances from the system.
    Utils.kill_processes!()

    {:ok, _} = ChromicPDF.start_link()

    Benchee.run(
      %{
        "chromic_pdf" => &chromic/1,
        "pdf_generator" => &pdf_generator/1,
        "puppeteer_pdf" => &puppeteer_pdf/1
      },
      inputs: %{
        "short" => Utils.content("short"),
        "long" => Utils.content("long")
      },
      warmup: 10,
      time: 60
    )
  end

  defp chromic(content) do
    ChromicPDF.print_to_pdf({:html, content}, output: fn _path -> nil end)
  end

  defp pdf_generator(content) do
    {:ok, _filename} =
      PdfGenerator.generate(
        content,
        generator: :chrome,
        prefer_system_executable: true,
        no_sandbox: true
      )
  end

  defp puppeteer_pdf(content) do
    {:ok, _} = PuppeteerPdf.Generate.from_string(content, "puppeteer.pdf")
  end
end
