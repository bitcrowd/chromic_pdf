defmodule ChromicPDF.ZUGFeRDTest do
  use ExUnit.Case, async: false
  import ChromicPDF.Utils, only: [system_cmd!: 2]
  require EEx

  @test_html Path.expand("../fixtures/test.html", __ENV__.file)
  @zugferd_invoice_xml Path.expand("../fixtures/zugferd-invoice.xml", __ENV__.file)
  @embed_xml_ps_eex Path.expand("../fixtures/embed_xml.ps.eex", __ENV__.file)

  @external_resource @embed_xml_ps_eex
  EEx.function_from_file(:defp, :render_embed_xml_ps, @embed_xml_ps_eex, [:assigns])

  describe "generating ZUGFeRD-compliant invoices" do
    defp print_to_pdfa(opts, cb) do
      opts = Keyword.put(opts, :output, cb)
      assert {:ok, _} = ChromicPDF.print_to_pdfa({:url, "file://#{@test_html}"}, opts)
    end

    setup do
      {:ok, _pid} = start_supervised(ChromicPDF)
      :ok
    end

    @tag :zuv
    test "the PDF/A converter can run additional PostScript" do
      embed_xml_ps =
        render_embed_xml_ps(
          zugferd_xml: @zugferd_invoice_xml,
          zugferd_xml_file_date: ChromicPDF.Utils.to_postscript_date(DateTime.utc_now())
        )

      pdfa_opts = [
        pdfa_def_ext: embed_xml_ps
      ]

      print_to_pdfa(pdfa_opts, fn file ->
        output =
          system_cmd!(
            "java",
            ["-jar", System.fetch_env!("ZUV_JAR"), "--action", "validate", "-f", file]
          )

        assert String.contains?(output, ~S(validationReports compliant="1"))
      end)
    end
  end
end
