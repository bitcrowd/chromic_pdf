defmodule ChromicPDF.Connection.Tokenizer do
  @moduledoc false

  @type t :: list()

  # Returns initial memo.
  def init do
    []
  end

  # Returns {[msgs(), memo()]}, msgs can be consumed, memo should be saved for next data blob.
  def tokenize(data, memo) do
    data
    |> String.split("\0")
    |> handle_chunks(memo)
  end

  defp handle_chunks([blob], memo), do: {[], [blob | memo]}
  defp handle_chunks([blob, ""], memo), do: {[join_chunks([blob | memo])], []}

  defp handle_chunks([blob | rest], memo) do
    msg = join_chunks([blob | memo])
    {msgs, memo} = handle_chunks(rest, [])
    {[msg | msgs], memo}
  end

  defp join_chunks(memo) do
    memo
    |> Enum.reverse()
    |> Enum.join()
  end
end
