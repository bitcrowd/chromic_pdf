# SPDX-License-Identifier: Apache-2.0

excludes =
  [
    verapdf: fn ->
      if System.find_executable("verapdf") do
        true
      else
        IO.puts("""
        Excluding '@tag :verapdf' tests.
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
        Excluding '@tag :pdfinfo' tests.
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
        Excluding '@tag :pdftotext' tests.
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
        Excluding '@tag :zuv' tests.
        If you want to run ZUV-based PDF/A tests, please download ZUV from
        https://github.com/ZUGFeRD/ZUV/releases and set the $ZUV_JAR
        environment variable to the container .jar file.
        """)

        false
      end
    end,
    identify: fn ->
      if System.find_executable("identify") do
        true
      else
        IO.puts("""
        Excluding '@tag :identify' tests.
        If you want to run identify-based image tests, please install imagemagick.
        """)

        false
      end
    end,
    docker: fn ->
      if System.find_executable("docker") do
        true
      else
        IO.puts("""
        Excluding '@tag :docker' tests.
        If you want to run docker-based image tests, please install docker.
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
