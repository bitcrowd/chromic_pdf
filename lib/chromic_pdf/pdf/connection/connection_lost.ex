# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.Connection.ConnectionLostError do
  @moduledoc """
  Exception raised when Chrome process has stopped unexpectedly.
  """

  defexception [:message]
end
