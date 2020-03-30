defmodule ChromicPdf.MixProject do
  use Mix.Project

  @version "0.3.0"

  def project do
    [
      app: :chromic_pdf,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      dialyzer: [plt_file: {:no_warn, ".plts/dialyzer.plt"}],
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases(),

      # ExUnit
      test_paths: test_paths(Mix.env()),

      # hex.pm
      package: package(),
      description: "Fast HTML-2-PDF/A renderer based on Chrome & Ghostscript",

      # hexdocs.pm
      name: "ChromicPDF",
      source_url: "https://github.com/bitcrowd/chromic_pdf",
      homepage_url: "https://github.com/bitcrowd/chromic_pdf",
      docs: [
        main: "ChromicPDF",
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      maintainers: ["@bitcrowd"],
      licenses: ["Apache-2.0"],
      links: %{github: "https://github.com/bitcrowd/chromic_pdf"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/unit/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp test_paths(:test), do: ["test/unit"]
  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_env), do: []

  defp deps do
    [
      {:jason, "~> 1.1"},
      {:poolboy, "~> 1.5"},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.2", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.21.3", only: [:test, :dev], runtime: false},
      {:junit_formatter, "~> 3.0", only: [:test, :integration]},
      {:mox, "~> 0.5.1", only: [:test]},
      {:plug, "~> 1.9", only: [:integration]},
      {:plug_cowboy, "~> 2.1", only: [:integration]}
    ]
  end

  defp aliases do
    [
      lint: [
        "format --check-formatted",
        "credo --strict",
        "dialyzer --format dialyxir"
      ]
    ]
  end
end
