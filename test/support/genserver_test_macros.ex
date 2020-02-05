defmodule ChromicPDF.GenServerTestMacros do
  @moduledoc false

  defmacro test_cast(name, expected_cast_value, do: block) do
    quote do
      test "it allows to cast a #{unquote(name)} command" do
        unquote(block)
        assert_receive {:"$gen_cast", unquote(expected_cast_value)}
      end
    end
  end
end
