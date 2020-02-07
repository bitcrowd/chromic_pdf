defmodule ChromicPDF.CallCountTest do
  use ExUnit.Case
  alias ChromicPDF.CallCount

  setup do
    {:ok, pid} = start_supervised(CallCount)
    %{pid: pid}
  end

  test "it starts at 1", %{pid: pid} do
    assert CallCount.bump(pid) == 1
  end

  test "it goes up and up and up", %{pid: pid} do
    assert Enum.map(1..5, fn _i -> CallCount.bump(pid) end) == [1, 2, 3, 4, 5]
  end
end
