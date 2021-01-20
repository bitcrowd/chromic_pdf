defmodule ChromicPDF.GetTargets do
  @moduledoc false

  import ChromicPDF.ProtocolMacros

  steps(increment_session_use_count: false) do
    call(:get_targets, "Target.getTargets", [], %{})
    await_response(:targets, ["targetInfos"])

    output("targetInfos")
  end

  @initial_wait_time 100

  def baseline do
    Process.sleep(@initial_wait_time)
    now()
  end

  def now do
    {:ok, target_infos} =
      ChromicPDF.Supervisor.with_services(ChromicPDF, fn services ->
        ChromicPDF.Browser.run_protocol(services.browser, __MODULE__, %{})
      end)

    for %{"targetId" => target_id, "url" => url} <- target_infos,
        String.ends_with?(url, "priv/blank.html"),
        do: target_id
  end
end
