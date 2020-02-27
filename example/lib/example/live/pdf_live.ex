defmodule Example.PDFLive do
  use Phoenix.LiveView
  import Phoenix.HTML
  alias Example.{HTMLForm, PageForm}

  defp tab_link(name, value, active) do
    ~E"""
    <li class="o-tab-list__item">
      <%= if active do %>
        <a href="#" class="button button-outline o-tab-list__item--active" phx-click="tab-select" phx-value-tab="<%= value %>"><%= name %></a>
      <% else %>
        <a href="#" class="button button-outline" phx-click="tab-select" phx-value-tab="<%= value %>"><%= name %></a>
      <% end %>
    </li>
    """
  end

  def render(assigns) do
    ~L"""
    <div class="l-columns">
      <div class="l-column c-preview">
        <iframe
          src="<%= @data %>"
          type="application/pdf"
          style="width: 100%; height: 100%;"
        ></iframe>
      </div>
      <div class="l-column c-editor">
        <ul class="o-tab-list" role="tablist">
          <%= tab_link("Body", "body", @active == :body) %>
          <%= tab_link("Header", "header", @active == :header) %>
          <%= tab_link("Footer", "footer", @active == :footer) %>
          <%= tab_link("Page", "page", @active == :page) %>
        </ul>
        <%=
          case @active do
            :page -> live_component(@socket, PageForm, page: @page)
            :body -> live_component(@socket, HTMLForm, name: "body", content: @body)
            :header -> live_component(@socket, HTMLForm, name: "header", content: @header)
            :footer -> live_component(@socket, HTMLForm, name: "footer", content: @footer)
          end
        %>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    socket
    |> assign(:page, %{
      # DIN A4: 21cm x 29,7cm
      paperWidth: 8.26772,
      paperHeight: 11.69291,

      # roughly DIN 5008: 27mm 10..20mm ?mm 25mm
      marginTop: 1.06299,
      marginRight: 0.787402,
      marginBottom: 0.787402,
      marginLeft: 0.787402,

      displayHeaderFooter: true,
    })
    |> assign(:header, "")
    |> assign(:footer, "")
    |> assign(:body, "Hello world!")
    |> assign(:active, :body)
    |> update_pdf()
    |> ok()
  end

  def handle_event("body-update", %{"html" => %{"content" => content}}, socket) do
    update_content(content, :body, socket)
  end

  def handle_event("header-update", %{"html" => %{"content" => content}}, socket) do
    update_content(content, :header, socket)
  end

  def handle_event("footer-update", %{"html" => %{"content" => content}}, socket) do
    update_content(content, :footer, socket)
  end

  def handle_event("page-update", params, socket) do
    # Don't do this.
    page = Map.new(params["page"], fn {k, v} -> {String.to_atom(k), v} end)

    socket
    |> assign(:page, page)
    |> update_pdf()
    |> noreply()
  end

  def handle_event("tab-select", %{"tab" => tab}, socket) do
    socket
    |> assign(:active, String.to_atom(tab))
    |> noreply()
  end

  defp update_content(content, name, socket) do
    socket
    |> assign(name, content)
    |> update_pdf()
    |> noreply()
  end

  defp update_pdf(socket) do
    print_to_pdf_opts =
      socket.assigns.page
      |> Map.put(:headerTemplate, socket.assigns.header)
      |> Map.put(:footerTemplate, socket.assigns.footer)

    {:ok, data} =
      ChromicPDF.print_to_pdf(
        {:html, socket.assigns.body},
        print_to_pdf: print_to_pdf_opts
      )

    assign(socket, :data, "data:application/pdf;base64,#{data}")
  end

  defp ok(socket), do: {:ok, socket}
  defp noreply(socket), do: {:noreply, socket}
end
