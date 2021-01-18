defmodule ChromicPDF.TestServer do
  @moduledoc false

  use Plug.Router

  @ports %{
    http: 44_285,
    https: 44_286
  }

  @cowboy_opts [
    http: [port: @ports[:http]],
    https: [
      port: @ports[:https],
      keyfile: Path.expand("../../fixtures/cert_key.pem", __ENV__.file),
      certfile: Path.expand("../../fixtures/cert.pem", __ENV__.file)
    ]
  ]

  plug(:fetch_cookies)
  plug(:match)
  plug(:dispatch)

  get "/hello" do
    send_resp(conn, 200, "Hello from TestServer")
  end

  get "/cookie_echo" do
    send_resp(conn, 200, inspect(conn.req_cookies))
  end

  def port(scheme), do: Map.fetch!(@ports, scheme)

  def cowboy(scheme) do
    {Plug.Cowboy, scheme: scheme, plug: __MODULE__, options: @cowboy_opts[scheme]}
  end
end
