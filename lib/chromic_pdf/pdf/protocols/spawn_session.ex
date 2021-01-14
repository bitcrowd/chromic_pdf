defmodule ChromicPDF.SpawnSession do
  @moduledoc false

  import ChromicPDF.Utils, only: [priv_asset: 1]
  import ChromicPDF.ProtocolMacros

  @version Mix.Project.config()[:version]

  def blank_url do
    "file://#{priv_asset("blank.html")}"
  end

  steps do
    call(:create_browser_context, "Target.createBrowserContext", [], %{"disposeOnDetach" => true})
    await_response(:browser_context_created, ["browserContextId"])

    call(:create_target, "Target.createTarget", ["browserContextId"], %{"url" => "about:blank"})
    await_response(:target_created, ["targetId"])

    call(:attach, "Target.attachToTarget", ["targetId"], %{"flatten" => true})

    await_notification(
      :attached,
      "Target.attachedToTarget",
      [{["targetInfo", "targetId"], "targetId"}],
      ["sessionId"]
    )

    call(:set_user_agent, "Emulation.setUserAgentOverride", [], %{
      "userAgent" => "ChromicPDF #{@version}"
    })

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

    if_option {:ignore_certificate_errors, true} do
      call(:ignore_certificate_errors, "Security.setIgnoreCertificateErrors", [], %{
        "ignore" => true
      })

      await_response(:certificate_errors_ignored, [])
    end

    call(:enable_page, "Page.enable", [], %{})
    await_response(:page_enabled, [])

    call(:blank, "Page.navigate", [], %{"url" => blank_url()})
    await_response(:blanked, ["frameId"])
    await_notification(:fsl_after_blank, "Page.frameStoppedLoading", ["frameId"], [])

    output(["targetId", "sessionId"])
  end
end
