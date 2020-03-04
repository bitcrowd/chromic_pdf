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

    if_option {:offline, true} do
      call(
        :offline_mode,
        "Network.emulateNetworkConditions",
        [],
        %{
          "offline" => true,
          "latency" => 0,
          "downloadThroughput" => 0,
          "uploadThroughput" => 0
        }
      )
    end

    call(:enable_page, "Page.enable", [], %{})

    reply("sessionId")
  end
end
