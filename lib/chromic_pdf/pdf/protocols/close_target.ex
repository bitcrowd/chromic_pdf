# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.CloseTarget do
  @moduledoc false

  import ChromicPDF.ProtocolMacros

  steps do
    call(:detach_from_target, "Target.detachFromTarget", [:sessionId, :targetId], %{})
    await_response(:detached_from_target, [])

    call(:dispose_browser_context, "Target.disposeBrowserContext", [:browserContextId], %{})
    await_response(:browser_context_disposed, [])

    output([])
  end
end
