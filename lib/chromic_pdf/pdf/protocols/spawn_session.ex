defmodule ChromicPDF.SpawnSession do
  @moduledoc false

  import ChromicPDF.ProtocolMacros
  alias ChromicPDF.Protocol

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

    call(
      :set_offline_mode,
      "Network.emulateNetworkConditions",
      [],
      %{
        "offline" => true,
        "latency" => 0,
        "downloadThroughput" => 0,
        "uploadThroughput" => 0
      }
    )

    call(:enable_page, "Page.enable", [], %{})

    reply("sessionId")
  end

  def new(args) do
    offline = Keyword.get(args, :offline, true)
    opts = (offline && []) || [exclude: [:set_offline_mode]]

    opts
    |> build_steps()
    |> Enum.reject(&is_nil/1)
    |> Protocol.new()
  end
end
