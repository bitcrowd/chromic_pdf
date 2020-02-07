defmodule ChromicPDF.ConnectionTest do
  use ExUnit.Case
  import Mox
  import ChromicPDF.Connection
  import ChromicPDF.GenServerTestMacros
  alias ChromicPDF.ChromeMock

  @port :some_port
  @ref :some_ref

  defp new_state do
    %{
      parent_pid: self(),
      data: [],
      port: @port
    }
  end

  defp new_state(_) do
    %{state: new_state()}
  end

  describe "API" do
    test_cast ":send_msg", {:send_msg, "foo"} do
      send_msg(self(), "foo")
    end
  end

  describe "initialization" do
    test "it spawns Chrome and initializes its state" do
      expect(ChromeMock, :spawn, fn -> {:ok, @port} end)
      assert init(self()) == {:ok, new_state()}
    end
  end

  describe "external process supervision" do
    setup [:new_state]

    test "it stops the GenServer when Chrome dies", %{state: state} do
      assert handle_info({:DOWN, @ref, :port, @port, 127}, state) ==
               {:stop, :chrome_has_crashed, state}
    end
  end

  describe "graceful termination" do
    setup [:new_state]

    test "it stops the spawned Chrome instance when terminated", %{state: state} do
      expect(ChromeMock, :stop, fn @port -> :ok end)
      terminate(:normal, state)
    end
  end

  describe "incoming messages" do
    setup [:new_state]

    defp msg_chain_out(state, msgs) do
      Enum.reduce(msgs, state, fn msg, s ->
        assert {:noreply, ns} = handle_info({@port, {:data, msg}}, s)
        ns
      end)
    end

    defp assert_msg_in(msg) do
      assert_receive({:msg_in, ^msg})
    end

    test "it passes received messages to its parent", %{state: state} do
      msg_chain_out(state, ["foo\0"])
      assert_msg_in("foo")
    end

    test "it can receive multiple messages in a chunk", %{state: state} do
      msg_chain_out(state, ["foo\0bar\0"])
      assert_msg_in("foo")
      assert_msg_in("bar")
    end

    test "it can receive a long message crossing chunks", %{state: state} do
      msg_chain_out(state, ["foo", "bar\0"])
      assert_msg_in("foobar")
    end
  end

  describe "outgoing messages" do
    setup [:new_state]

    test "it forwards outgoing messages to Chrome", %{state: %{port: port} = state} do
      expect(ChromeMock, :send_msg, fn ^port, "foo" -> :ok end)
      assert handle_cast({:send_msg, "foo"}, state) == {:noreply, state}
    end
  end
end
