defmodule PhoenixExample do
  @moduledoc false

  def pdf do
    quote do
      use Phoenix.View, root: "examples/phoenix/templates"
      import Phoenix.HTML
      import PhoenixExample

      def print_to_pdf(assigns, callback) do
        [content: content(assigns), size: :a4]
        |> ChromicPDF.Template.source_and_options()
        |> ChromicPDF.print_to_pdf(output: callback)
      end

      Module.register_attribute(__MODULE__, :assets, accumulate: true)
      @before_compile PhoenixExample
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  defmacro __before_compile__(_env) do
    quote do
      def render_asset(filename), do: render_asset(@assets, filename)
    end
  end

  defmacro load_asset(filename) do
    path = path_to_asset(filename)

    quote do
      @external_resource unquote(path)
      @assets {unquote(filename), File.read!(unquote(path))}
    end
  end

  defp path_to_asset("logo.png"), do: "assets/social.png"
  defp path_to_asset(filename), do: Path.join("examples/phoenix/assets", filename)

  def render_asset(assets, filename) do
    assets
    |> find_asset(filename)
    |> do_render_asset(Path.extname(filename))
    |> Phoenix.HTML.raw()
  end

  defp find_asset(assets, filename) do
    Enum.find_value(assets, fn
      {^filename, asset} -> asset
      _ -> nil
    end) || raise("no asset called #{filename}")
  end

  defp do_render_asset(asset, ".png") do
    ~s(<img src="data:image/png;base64,#{Base.encode64(asset)}" />)
  end

  defp do_render_asset(asset, ".css") do
    ~s(<style type="text/css">#{asset}</style>)
  end
end
