defmodule ChromicPDF.ConnectionTest do
  use ExUnit.Case
  import Mox
  import ChromicPDF.Connection
  alias ChromicPDF.ChromeMock

  @port :some_port
  @ref :some_ref

  defp new_state do
    %{
      port: @port,
      parent_pid: self(),
      tokenizer: [],
      dispatcher: %ChromicPDF.Connection.Dispatcher{
        next_call_id: 1,
        port: @port
      }
    }
  end

  defp new_state(_) do
    %{state: new_state()}
  end

  describe "initialization" do
    test "it spawns Chrome and initializes its state" do
      opts = [
        discard_stderr: false,
        no_sandbox: true,
        chrome_executable: "/custom/chrome",
        chrome_args: "--foo"
      ]

      expect(ChromeMock, :spawn, fn ^opts -> {:ok, @port} end)
      assert init({self(), opts}) == {:ok, new_state()}
    end
  end

  describe "external process supervision" do
    setup [:new_state]

    test "it suicides when Chrome is terminated externally", %{state: state} do
      assert handle_info({:EXIT, @port, :normal}, state) ==
               {:stop, :connection_lost, state}

      assert handle_info({:EXIT, @port, :other_reason}, state) ==
               {:stop, :connection_lost, state}
    end
  end

  describe "graceful shutdown" do
    setup [:new_state]

    test "it gracefully closes Chrome on shutdown", %{state: %{dispatcher: %{port: port}} = state} do
      expected_msg = ~s({"id":1,"method":"Browser.close","params":{}})
      expect(ChromeMock, :send_msg, fn ^port, ^expected_msg -> :ok end)

      # Inject :DOWN message before calling terminate/2 to avoid locking in receive.
      send(self(), {:DOWN, @ref, :port, @port, 0})

      assert terminate(:shutdown, state) == :ok
    end
  end

  describe "incoming messages" do
    setup [:new_state]

    test "stores incomplete messages in the tokenizer memo", %{state: state} do
      assert {:noreply, %{tokenizer: ["foo"]}} = handle_info({@port, {:data, "foo"}}, state)
    end

    test "decodes complete messages and sends them to parent", %{state: state} do
      handle_info({@port, {:data, "{}\0"}}, state)
      assert_receive {:msg_in, %{}}
    end
  end

  describe "outgoing messages" do
    setup [:new_state]

    test "it encodes messages and sends them to Chrome", %{
      state: %{dispatcher: %{port: port}} = state
    } do
      expected_msg = ~s({"id":1,"method":"method","params":{}})
      expect(ChromeMock, :send_msg, fn ^port, ^expected_msg -> :ok end)

      assert {:reply, 1, %{dispatcher: %{next_call_id: 2}}} =
               handle_call({:dispatch_call, {"method", %{}}}, {self(), @ref}, state)
    end
  end
end
