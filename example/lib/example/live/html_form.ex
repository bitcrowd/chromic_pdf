defmodule Example.HTMLForm do
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  def render(assigns) do
    ~L"""
    <%= f = form_for :html, "#", [phx_submit: "#{@name}-update"] %>
      <%= submit "Update" %>
      <label for="<%= @name %>">
        <span>HTML</span>
        <%= textarea f, "content", rows: 50, value: @content %>
      </label>
    </form>
    """
  end
end
