# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.DynamicNameTest do
  use ExUnit.Case, async: false

  @moduletag pool_size: 1

  describe "when on_demand is false" do
    setup :spawn_instances

    test "put_dynamic_name is used correctly" do
      run_tests()
    end
  end

  describe "when on_demand is true" do
    @describetag :on_demand

    setup :spawn_instances

    test "put_dynamic_name is used correctly" do
      run_tests()
    end
  end

  defp spawn_instances(ctx) do
    on_demand = Map.get(ctx, :on_demand, false)

    start_supervised!(
      {ChromicPDF, name: Foo, on_demand: on_demand, session_pool: [size: ctx.pool_size]}
      |> with_id(Foo)
    )

    start_supervised!(
      {ChromicPDF, name: Bar, on_demand: on_demand, session_pool: [size: ctx.pool_size]}
      |> with_id(Bar)
    )

    :ok
  end

  defp run_tests do
    assert ChromicPDF.put_dynamic_name(Foo) == ChromicPDF
    assert {:ok, _} = ChromicPDF.print_to_pdf({:html, ""})

    assert ChromicPDF.put_dynamic_name(Bar) == Foo
    assert {:ok, _} = ChromicPDF.print_to_pdf({:html, ""})

    ChromicPDF.put_dynamic_name(Oops)

    assert_raise RuntimeError, ~r/Can't find a running ChromicPDF instance./, fn ->
      ChromicPDF.print_to_pdf({:html, ""})
    end
  end

  defp with_id(child_spec, id) do
    Supervisor.child_spec(child_spec, id: id)
  end
end
