# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.Browser.ExecutionError do
  @moduledoc """
  Exception in interaction with the session pool.
  """

  defexception [:message]
end
