# SPDX-License-Identifier: Apache-2.0

# credo:disable-for-this-file Credo.Check.Readability.LargeNumbers
defmodule ChromicPDF.InetConnectionTest do
  use ChromicPDF.Case, async: false
  import ChromicPDF.TestAPI
  import ChromicPDF.Utils, only: [find_supervisor_child: 2]
  alias ChromicPDF.{TestDockerChrome, TestInetChrome}

  @chrome_spawn_wait_time 600
  @docker_spawn_wait_time 1000

  # NOTE: Each test has its own port as process teardown is async and sometimes takes too long.

  describe "connecting to Chrome via network" do
    setup %{port: port} do
      start_supervised!({TestInetChrome, port: port})
      Process.sleep(@chrome_spawn_wait_time)

      start_supervised!({ChromicPDF, chrome_address: {"localhost", port}})

      :ok
    end

    # Test exists to demonstrate that we start the correct GenServer and really do not launch
    # another external Chrome (= and hence the rest of these tests work properly).
    @tag port: 29222
    test ":chrome_address: option spawns the Inet connection process" do
      browser_pid = find_supervisor_child(ChromicPDF, ChromicPDF.Browser)
      assert is_pid(browser_pid)

      channel_pid = find_supervisor_child(browser_pid, ChromicPDF.Browser.Channel)
      assert is_pid(channel_pid)

      {:links, links} = Process.info(channel_pid, :links)
      assert [connection_pid] = links -- [browser_pid]

      {:dictionary, dict} = Process.info(connection_pid, :dictionary)
      assert Keyword.fetch!(dict, :"$initial_call") == {ChromicPDF.Connection.Inet, :init, 1}
    end

    @tag pdftotext: true, port: 29223
    test "it prints PDF as usual" do
      # file:// URLs
      print_to_pdf(fn text ->
        assert String.contains?(text, "Hello ChromicPDF!")
      end)

      # https:// URLs
      print_to_pdf({:url, "https://example.net"}, fn text ->
        assert String.contains?(text, "Example Domain")
      end)

      # HTML content
      print_to_pdf({:html, test_html()}, fn text ->
        assert String.contains?(text, "Hello ChromicPDF!")
      end)
    end

    @tag pdftotext: true, port: 29224
    test "recovers when connection is lost", %{port: port} do
      # Kills the external Chrome process as well, simulating a network issue.
      stop_supervised!(TestInetChrome)
      Process.sleep(@chrome_spawn_wait_time)

      start_supervised!({TestInetChrome, port: port})
      Process.sleep(@chrome_spawn_wait_time)

      print_to_pdf(fn text ->
        assert String.contains?(text, "Hello ChromicPDF!")
      end)
    end
  end

  describe "connecting to Chrome in Zenika/alpine-chrome container" do
    setup %{port: port} do
      start_supervised!({TestDockerChrome, port: port})
      Process.sleep(@chrome_spawn_wait_time + @docker_spawn_wait_time)

      start_supervised!({ChromicPDF, chrome_address: {"localhost", port}})

      :ok
    end

    @tag docker: true, pdftotext: true, port: 29225
    test "running chrome in Zenika/alpine-chrome container and connecting to it works" do
      print_to_pdf({:html, test_html()}, fn text ->
        assert String.contains?(text, "Hello ChromicPDF!")
      end)
    end
  end
end
