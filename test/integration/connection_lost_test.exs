defmodule ChromicPDF.ConnectionLostTest do
  use ExUnit.Case, async: false
  alias ChromicPDF.Connection
  alias ChromicPDF.Connection.ConnectionLostError

  describe "when the Chrome process fails at startup or is killed externally" do
    @tag :capture_log
    test "an exception with a nice error message is raised" do
      {:ok, pid} = Connection.start_link(self(), [])

      port_info = Connection.port_info(pid)

      Process.unlink(pid)
      Process.monitor(pid)

      System.cmd("kill", [to_string(port_info[:os_pid])])

      receive do
        {:DOWN, _ref, :process, ^pid, {%ConnectionLostError{message: msg}, _trace}} ->
          assert String.contains?(
                   msg,
                   "Chrome has stopped or was terminated by an external program."
                 )
      end
    end
  end
end
