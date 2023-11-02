defmodule ChromicPDF.Case do
  @moduledoc false

  use ExUnit.CaseTemplate

  setup context do
    if {:disable_logger, true} in context do
      Logger.remove_backend(:console)
      on_exit(fn -> Logger.add_backend(:console) end)
    end

    :ok
  end
end
