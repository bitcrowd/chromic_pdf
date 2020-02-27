defmodule Example.PageForm do
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  def render(assigns) do
    ~L"""
    <%= f = form_for :page, "#", [phx_submit: "page-update"] %>
      <%= submit "Update" %>
      <label for="paperWidth">
        <span>Paper Width (in)</span>
        <%= number_input f, "paperWidth", value: @page.paperWidth %>
      </label>
      <label for="paperHeight">
        <span>Paper Height (in)</span>
        <%= number_input f, "paperHeight", value: @page.paperHeight %>
      </label>
      <label for="marginTop">
        <span>Margin Top (in)</span>
        <%= number_input f, "marginTop", value: @page.marginTop %>
      </label>
      <label for="marginRight">
        <span>Margin Right (in)</span>
        <%= number_input f, "marginRight", value: @page.marginRight %>
      </label>
      <label for="marginBottom">
        <span>Margin Bottom (in)</span>
        <%= number_input f, "marginBottom", value: @page.marginBottom %>
      </label>
      <label for="marginLeft">
        <span>Margin Left (in)</span>
        <%= number_input f, "marginLeft", value: @page.marginLeft %>
      </label>
    </form>
    """
  end
end
