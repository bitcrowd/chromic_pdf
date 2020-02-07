defmodule ChromicPDF.Chrome do
  @moduledoc false

  @callback spawn() :: {:ok, port()}
  @callback stop(port()) :: :ok
  @callback send_msg(port(), msg :: binary()) :: :ok
end
