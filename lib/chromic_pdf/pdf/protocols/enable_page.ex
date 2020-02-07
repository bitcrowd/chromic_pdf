defmodule ChromicPDF.EnablePage do
  @moduledoc false

  # Protocol enables page notifications and exits immediately.

  use ChromicPDF.Protocol

  @impl ChromicPDF.Protocol
  def init(_from, _params, dispatcher) do
    dispatcher.({"Page.enable", %{}})

    {:done, :ok}
  end
end
