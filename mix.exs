# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPdf.MixProject do
  use Mix.Project

  @source_url "https://github.com/bitcrowd/chromic_pdf"
  @version "1.8.0"

  def project do
    [
      app: :chromic_pdf,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      dialyzer: [plt_add_apps: [:ex_unit, :mix], plt_file: {:no_warn, ".plts/dialyzer.plt"}],
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases(),

      # hex.pm
      package: package(),

      # hexdocs.pm
      name: "ChromicPDF",
      source_url: @source_url,
      homepage_url: @source_url,
      docs: [
        main: "ChromicPDF",
        logo: "assets/icon.png",
        extras: [
          "README.md": [title: "Read Me"],
          "CHANGELOG.md": [title: "Changelog"],
          LICENSE: [title: "License"]
        ],
        skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
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
  defp elixirc_paths(:test), do: ["examples", "lib", "test"]
  defp elixirc_paths(:prod), do: ["lib"]

  defp deps do
    [
      {:jason, "~> 1.1"},
      {:nimble_pool, "~> 0.2 or ~> 1.0"},
      {:telemetry, "~> 0.4 or ~> 1.0"},
      {:dialyxir, "~> 1.2", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: [:test, :dev], runtime: false},
      {:junit_formatter, "~> 3.1", only: [:test]},
      {:mox, "~> 1.0", only: [:test]},
      {:phoenix, "~> 1.5", only: [:dev, :test]},
      {:phoenix_html, "~> 3.0", only: [:dev, :test]},
      {:plug, "~> 1.11", only: [:dev, :test]},
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
