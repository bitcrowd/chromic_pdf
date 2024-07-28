# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.GetTargets do
  @moduledoc false

  import ChromicPDF.ProtocolMacros

  steps do
    call(:get_targets, "Target.getTargets", [], %{})
    await_response(:targets, ["targetInfos"])

    output("targetInfos")
  end

  def run do
    {:ok, target_infos} = ChromicPDF.run_protocol(__MODULE__, skip_session_use_count: true)

    for %{"targetId" => target_id, "url" => url} <- target_infos,
        String.ends_with?(url, "priv/blank.html"),
        do: target_id
  end
end
