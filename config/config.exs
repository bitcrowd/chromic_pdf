# SPDX-License-Identifier: Apache-2.0

import Config

# Set this to true to see protocol messages.
config :chromic_pdf, debug_protocol: false

if Mix.env() in [:dev, :test] do
  config :chromic_pdf, dev_pool_size: 1
end
