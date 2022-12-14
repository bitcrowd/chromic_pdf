defmodule Utils do
  # Long is roughly 20 pages.
  @short "Fruitcake lollipop tootsie roll cotton candy dessert. Pudding danish bonbon jelly beans wafer toffee oat cake croissant macaroon. Gingerbread lollipop tiramisu. Macaroon gummi bears cake macaroon jelly beans toffee."
  @long Enum.map(1..500, fn _ -> @short end) |> Enum.join("<br>")

  def content("short"), do: @short
  def content("long"), do: @long

  def kill_processes! do
    kill_processes!("Chrome")
    kill_processes!("puppeteer")
  end

  defp kill_processes!(pattern) do
    :os.cmd(:"ps aux | grep #{pattern} | awk '{print $2;}' | xargs kill")
  end
end
