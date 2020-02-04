import Config

if Mix.env() == :test do
  config :chromic_pdf, :chrome, ChromicPDF.ChromeMock
end
