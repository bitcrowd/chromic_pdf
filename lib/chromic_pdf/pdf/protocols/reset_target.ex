defmodule ChromicPDF.ResetTarget do
  @moduledoc false

  import ChromicPDF.ProtocolMacros
  import ChromicPDF.Utils, only: [priv_asset: 1]

  defp blank_url do
    "file://#{priv_asset("blank.html")}"
  end

  steps do
    call(:reset_history, "Page.resetNavigationHistory", [], %{})
    await_response(:history_reset, [])

    if_option :set_cookie do
      call(:clear_cookies, "Network.clearBrowserCookies", [], %{})
      await_response(:cleared, [])
    end

    call(:blank, "Page.navigate", [], %{"url" => blank_url()})
    await_response(:blanked, ["frameId"])
    await_notification(:fsl_after_blank, "Page.frameStoppedLoading", ["frameId"], [])
  end
end
