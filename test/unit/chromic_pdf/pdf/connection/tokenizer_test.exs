defmodule ChromicPDF.Connection.TokenizerTest do
  use ExUnit.Case, async: true
  import ChromicPDF.Connection.Tokenizer

  describe "tokenizing incoming messages" do
    test "single message" do
      assert tokenize("foo\0", []) == {["foo"], []}
    end

    test "single message with previous chunks" do
      assert tokenize("foo\0", ["bar", "baz"]) == {["bazbarfoo"], []}
    end

    test "incomplete message" do
      assert tokenize("foo", []) == {[], ["foo"]}
    end

    test "complete message followed by incomplete message" do
      assert tokenize("foo\0bar", []) == {["foo"], ["bar"]}
    end
  end
end
