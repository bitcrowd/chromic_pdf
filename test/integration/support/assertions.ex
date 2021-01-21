defmodule ChromicPDF.Assertions do
  @moduledoc false

  import ExUnit.Assertions, only: [assert: 1]

  @attempts 20
  @delay 50

  def assert_continuously(fetch_fun, check_fun) do
    for _ <- 1..@attempts do
      assert(fetch_fun.() |> check_fun.())
      Process.sleep(@delay)
    end
  end

  def assert_eventually(fetch_fun, check_fun) do
    assert {:ok, data} = do_assert_eventually(fetch_fun, check_fun)
    data
  end

  defp do_assert_eventually(fetch_fun, check_fun) do
    Enum.reduce_while(1..@attempts, :attempts_exceeded, fn _attempt, acc ->
      data = fetch_fun.()

      if check_fun.(data) do
        {:halt, {:ok, data}}
      else
        Process.sleep(@delay)
        {:cont, acc}
      end
    end)
  end
end
