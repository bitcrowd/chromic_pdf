import Config

if Mix.env() == :test do
  config :chromic_pdf, chrome: ChromicPDF.ChromeMock
end

if Mix.env() in [:test, :integration, :dev] do
  config :chromic_pdf, dev_pool_size: 1
end

if Mix.env() in [:integration, :dev] do
  import_config "../examples/phoenix/config.exs"
end
