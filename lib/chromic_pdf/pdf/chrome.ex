defmodule ChromicPDF.Chrome do
  @moduledoc false

  @callback spawn(keyword()) :: {:ok, port()}
  @callback stop(port()) :: :ok
  @callback send_msg(port(), msg :: binary()) :: :ok
end
