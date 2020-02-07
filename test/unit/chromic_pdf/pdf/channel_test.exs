defmodule ChromicPDF.ChannelTest do
  use ExUnit.Case

  defmodule TestChannel do
    use ChromicPDF.Channel

    def upstream(msg) do
      send(self(), {:msg_out, msg})
    end

    @impl ChromicPDF.Channel
    def init_upstream(args) do
      send(self(), {:upstream_initialized, args})
      &ChromicPDF.ChannelTest.upstream/1
    end
  end

  describe "initialization" do
    test "it initializes upstream and the call count" do
      {:ok, state} = TestChannel.init(:args)

      assert_received {:upstream_initialized, :args}

      assert is_function(state.upstream)
      assert is_pid(state.call_count)

      Agent.stop(state.call_count)
    end
  end
end
