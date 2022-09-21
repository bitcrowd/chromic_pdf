# SPDX-License-Identifier: Apache-2.0

import Config

# Silence a warning phoenix emits if the json_library isn't configured.
config :phoenix, :json_library, Jason
