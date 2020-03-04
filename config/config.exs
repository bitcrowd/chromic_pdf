import Config

config :chromic_pdf, test_server_port: 44285

if Mix.env() == :test do
  config :chromic_pdf, chrome: ChromicPDF.ChromeMock
end

if Mix.env() in [:test, :integration, :dev] do
  config :chromic_pdf, default_pool_size: 1
end
