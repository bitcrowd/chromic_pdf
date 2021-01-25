defmodule PhoenixExample.InvoiceView do
  @moduledoc false

  use PhoenixExample, :pdf

  load_asset("style.css")
  load_asset("logo.png")

  defp content(assigns) do
    Phoenix.HTML.safe_to_string(render("body.html", assigns))
  end

  # ---- dummy params ----

  @dummy %{
    invoice_items: [
      %{description: "Shoes", price: 120},
      %{description: "Pants", price: 90}
    ]
  }

  def dummy(callback) do
    print_to_pdf(@dummy, callback)
  end

  # ---- view helpers ----

  defp sum(invoice_items) do
    Enum.reduce(invoice_items, 0, fn %{price: price}, acc -> acc + price end)
  end
end
