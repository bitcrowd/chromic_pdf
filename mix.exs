defmodule ChromicPdf.MixProject do
  use Mix.Project

  @source_url "https://github.com/bitcrowd/chromic_pdf"
  @version "1.2.0"

  def project do
    [
      app: :chromic_pdf,
      version: @version,
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      dialyzer: [plt_file: {:no_warn, ".plts/dialyzer.plt"}],
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases(),

      # ExUnit
      test_paths: test_paths(Mix.env()),

      # hex.pm
      package: package(),

      # hexdocs.pm
      name: "ChromicPDF",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: [
        extras: [
          "CHANGELOG.md": [title: "Changelog"],
          LICENSE: [title: "License"],
          "README.md": [title: "Overview"]
        ],
        skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
        main: "readme",
        source_url: @source_url,
        source_ref: "v#{@version}",
        formatters: ["html"],
        assets: "assets"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:eex, :logger]
    ]
  end

  defp package do
    [
      description: "Fast HTML-2-PDF/A renderer based on Chrome & Ghostscript",
      maintainers: ["@bitcrowd"],
      licenses: ["Apache-2.0"],
      links: %{
        Changelog: "https://hexdocs.pm/chromic_pdf/changelog.html",
        GitHub: @source_url
      }
    ]
  end

  defp elixirc_paths(:dev), do: ["examples", "lib"]
  defp elixirc_paths(:integration), do: ["examples", "lib", "test/integration/support"]
  defp elixirc_paths(:test), do: ["lib", "test/unit/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp test_paths(:test), do: ["test/unit"]
  defp test_paths(:integration), do: ["test/integration"]
  defp test_paths(_env), do: []

  defp deps do
    [
      {:jason, "~> 1.1"},
      {:nimble_pool, "~> 0.2.3"},
      {:telemetry, "~> 0.4 or ~> 1.0"},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: [:test, :dev], runtime: false},
      {:junit_formatter, "~> 3.1", only: [:test, :integration]},
      {:mox, "~> 1.0", only: [:test]},
      {:phoenix, "~> 1.5", only: [:dev, :integration]},
      {:phoenix_html, "~> 2.14", only: [:dev, :integration]},
      {:plug, "~> 1.11", only: [:dev, :integration]},
      {:plug_cowboy, "~> 2.4", only: [:integration]},

      # NOTE: cowboy 2.9.0 fails with ranch error
      {:cowboy, "< 2.9.0", only: [:integration]}
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
