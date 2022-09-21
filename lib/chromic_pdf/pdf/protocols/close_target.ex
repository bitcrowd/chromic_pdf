# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.CloseTarget do
  @moduledoc false

  import ChromicPDF.ProtocolMacros

  steps do
    call(:close_target, "Target.closeTarget", [:targetId], %{})
    await_response(:target_closed, ["success"])
    output("success")
  end
end
