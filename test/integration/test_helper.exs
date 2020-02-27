excludes =
  [
    verapdf: fn ->
      if System.find_executable("verapdf") do
        true
      else
        IO.puts("""
        Excluding verapdf validation tests.
        If you want to run verapdf-based PDF/A tests, make sure verapdf is in your $PATH.
        """)

        false
      end
    end,
    pdfinfo: fn ->
      if System.find_executable("pdfinfo") do
        true
      else
        IO.puts("""
        Excluding pdfinfo metadata tests.
        If you want to run pdfinfo-based PDF/A tests, please install poppler-utils / xpdf.
        """)

        false
      end
    end,
    pdftotext: fn ->
      if System.find_executable("pdftotext") do
        true
      else
        IO.puts("""
        Excluding pdftotext tests.
        If you want to run pdftotext-based PDF tests, please install poppler-utils / xpdf.
        """)

        false
      end
    end,
    zuv: fn ->
      if System.get_env("ZUV_JAR") do
        true
      else
        IO.puts("""
        Excluding ZUV (ZUGFeRD validator) validation tests.
        If you want to run ZUV-based PDF/A tests, please download ZUV from
        https://github.com/ZUGFeRD/ZUV/releases and set the $ZUV_JAR
        environment variable to the container .jar file.
        """)

        false
      end
    end
  ]
  |> Enum.reject(fn {_, check} -> check.() end)
  |> Enum.map(fn {tool, _} -> tool end)

ExUnit.configure(
  formatters: [JUnitFormatter, ExUnit.CLIFormatter],
  exclude: [:skip | excludes]
)

ExUnit.start()
