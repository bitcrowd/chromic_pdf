# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPdf.MixProject do
  use Mix.Project

  @source_url "https://github.com/bitcrowd/chromic_pdf"
  @version "1.15.2"

  def project do
    [
      app: :chromic_pdf,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      dialyzer: [
        plt_add_apps: [:ex_unit, :mix, :websockex, :inets, :phoenix_html, :plug, :plug_crypto],
        plt_file: {:no_warn, ".plts/dialyzer.plt"}
      ],
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases(),

      # hex.pm
      package: package(),

      # hexdocs.pm
      name: "ChromicPDF",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:eex, :inets, :logger]
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

  defp elixirc_paths(:dev), do: ["lib"]
  defp elixirc_paths(:test), do: ["lib", "test"]
  defp elixirc_paths(:prod), do: ["lib"]

  defp docs do
    [
      source_ref: "v#{@version}",
      main: "ChromicPDF",
      logo: "assets/icon.png",
      extras: [
        "README.md": [title: "Read Me"],
        "CHANGELOG.md": [title: "Changelog"],
        LICENSE: [title: "License"]
      ],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      formatters: ["html"],
      assets: "assets"
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.1"},
      {:nimble_pool, "~> 0.2 or ~> 1.0"},
      {:plug, "~> 1.11", optional: true},
      {:plug_crypto, "~> 1.2 or ~> 2.0", optional: true},
      {:phoenix_html, "~> 2.14 or ~> 3.2 or ~> 4.0", optional: true},
      {:telemetry, "~> 0.4 or ~> 1.0"},
      {:websockex, ">= 0.4.3", optional: true},
      {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: [:test, :dev], runtime: false},
      {:junit_formatter, "~> 3.1", only: [:test]},
      {:bandit, "~> 0.5.11", only: [:test]}
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
