defmodule ChromicPDF.Assertions do
  @moduledoc false

  import ExUnit.Assertions, only: [assert: 1]

  @max_retries 20
  @wait_delay 50

  def assert_eventually(fetch_fun, check_fun \\ & &1) do
    assert {:ok, data} = do_assert_eventually(fetch_fun, check_fun)
    data
  end

  defp do_assert_eventually(fetch_fun, check_fun) do
    Enum.reduce_while(1..@max_retries, {:error, :max_retries_exceeded}, fn _attempt, acc ->
      data = fetch_fun.()

      if check_fun.(data) do
        {:halt, {:ok, data}}
      else
        :timer.sleep(@wait_delay)
        {:cont, acc}
      end
    end)
  end
end
