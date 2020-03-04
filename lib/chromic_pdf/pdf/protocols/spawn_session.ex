defmodule ChromicPDF.SpawnSession do
  @moduledoc false

  import ChromicPDF.ProtocolMacros

  steps do
    call(:create_target, "Target.createTarget", [], %{"url" => "about:blank"})
    await_response(:created, ["targetId"])

    call(:attach, "Target.attachToTarget", ["targetId"], %{"flatten" => true})

    await_notification(
      :attached,
      "Target.attachedToTarget",
      [{["targetInfo", "targetId"], "targetId"}],
      ["sessionId"]
    )

    call(:enable_page, "Page.enable", [], %{})

    reply("sessionId")
  end
end
