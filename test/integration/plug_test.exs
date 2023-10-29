# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.PlugTest do
  use ChromicPDF.Case, async: false
  use Plug.Test
  import ChromicPDF.TestAPI
  alias ChromicPDF.TestServer

  @moduletag :disable_logger

  describe "request forwarding via ChromicPDF.Plug" do
    setup do
      start_supervised!(ChromicPDF)
      start_supervised!(TestServer.bandit(:http))

      %{port: TestServer.port(:http)}
    end

    def render(conn, assigns) do
      Plug.Conn.send_resp(conn, 200, inspect(assigns))
    end

    @tag :pdftotext
    test "incoming Chrome request can be forwarded to MFA", %{port: port} do
      source =
        {:plug,
         url: "http://localhost:#{port}/with_plug",
         forward: {__MODULE__, :render, [%{hello: "world"}]}}

      print_to_pdf(source, fn text ->
        assert String.contains?(text, ~s(%{hello: "world"}))
      end)
    end

    @tag :pdftotext
    test "incoming Chrome request can be forwarded to function", %{port: port} do
      source =
        {:plug,
         url: "http://localhost:#{port}/with_plug",
         forward: fn conn -> Plug.Conn.send_resp(conn, 200, "HELLO") end}

      print_to_pdf(source, fn text ->
        assert String.contains?(text, "HELLO")
      end)
    end

    test "requests without cookie give a HTTP 403", %{port: port} do
      conn = conn(:get, "http://localhost:#{port}/with_plug")

      assert_raise ChromicPDF.Plug.MissingCookieError, fn ->
        ChromicPDF.Plug.call(conn, [])
      end
    end

    test "requests with invalid cookie give a HTTP 403", %{port: port} do
      conn =
        conn(:get, "http://localhost:#{port}/with_plug")
        |> put_req_header("cookie", "chromic_pdf_cookie=foo")

      assert_raise ChromicPDF.Plug.InvalidCookieError, fn ->
        ChromicPDF.Plug.call(conn, [])
      end
    end
  end
end
