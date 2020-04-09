defmodule ChromicPDF.CreateTarget do
  @moduledoc false

  import ChromicPDF.ProtocolMacros

  steps do
    call(:create_browser_context, "Target.createBrowserContext", [], %{"disposeOnDetach" => true})
    await_response(:browser_context_created, ["browserContextId"])

    call(:create_target, "Target.createTarget", ["browserContextId"], %{"url" => "about:blank"})
    await_response(:target_created, ["targetId"])

    reply("targetId")
  end
end
