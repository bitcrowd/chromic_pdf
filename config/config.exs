# SPDX-License-Identifier: Apache-2.0

import Config

# Set this to true to see protocol messages.
config :chromic_pdf, debug_protocol: false

if Mix.env() == :test do
  config :chromic_pdf, chrome: ChromicPDF.ChromeRunnerMock
end

if Mix.env() in [:test, :integration, :dev] do
  config :chromic_pdf, dev_pool_size: 1
end

if Mix.env() in [:integration, :dev] do
  import_config "../examples/phoenix/config.exs"
end
