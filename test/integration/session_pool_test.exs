# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.SessionPoolTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO
  import ExUnit.CaptureLog
  import ChromicPDF.Assertions
  import ChromicPDF.TestAPI
  alias ChromicPDF.GetTargets

  def assert_target_respawn(pool_size, fun) do
    # Wait for targets to become available.
    targets_before =
      assert_eventually(&GetTargets.run/0, fn targets ->
        length(targets) == pool_size
      end)

    fun.(targets_before)

    # Wait for targets to settle with exactly having been replaced.
    assert_eventually(&GetTargets.run/0, fn targets_now ->
      length(targets_now) == length(targets_before) &&
        length(targets_before -- targets_now) == 1 &&
        length(targets_now -- targets_before) == 1
    end)
  end

  describe "sessions automatically restart after a number of operations" do
    @pool_size 3

    defp assert_automatic_session_termination_after_max_uses do
      assert_target_respawn(@pool_size, fn targets_before ->
        # After the first print operation, the targetIds should remain exactly the same.
        print_to_pdf()

        assert_continuously(&GetTargets.run/0, fn targets_now ->
          targets_now == targets_before
        end)

        # After the second print operation, we expect the Session to have restarted its target
        # process, so exactly one targetId should have changed.
        print_to_pdf()
      end)
    end

    test "session restart spawns a new session process" do
      start_supervised!({ChromicPDF, session_pool: [max_uses: 2, size: @pool_size]})

      assert_automatic_session_termination_after_max_uses()
    end

    test ":session_max_uses option is supported but deprecated" do
      # This silences stderr but does not capture the warning as it comes from another process.
      assert capture_io(:stderr, fn ->
               start_supervised!(
                 {ChromicPDF, max_session_uses: 2, session_pool: [size: @pool_size]}
               )

               assert_automatic_session_termination_after_max_uses()
             end) =~ "deprecated"
    end
  end

  describe "init timeout" do
    test "can be configured and generates a nice error messages" do
      err =
        capture_log(fn ->
          start_supervised!({ChromicPDF, session_pool: [init_timeout: 10]})
          # wait for nimble pool to init
          :timer.sleep(100)
        end)

      assert err =~ "Timeout in Channel.run_protocol"
      assert err =~ "within the configured\n10 milliseconds"
      assert err =~ "%ChromicPDF.Protocol{"
      assert err =~ "SpawnSession"
    end
  end

  describe "worker timeout" do
    @pool_size 1

    setup do
      start_supervised!({ChromicPDF, session_pool: [size: @pool_size, timeout: 500]})

      :ok
    end

    test "can be configured and generates a nice error message" do
      assert_raise ChromicPDF.Browser.ExecutionError, ~r/Timeout in Channel.run_protocol/, fn ->
        print_to_pdf_delayed(1_000)
      end
    end

    test "error message includes an inspection of the current state of the protocol" do
      exception =
        assert_raise ChromicPDF.Browser.ExecutionError, fn ->
          print_to_pdf_delayed(1_000)
        end

      assert exception.message =~ "%ChromicPDF.Protocol{"
      refute exception.message =~ "Page.navigate"
    end

    test "timed out protocols are cancelled" do
      assert_target_respawn(@pool_size, fn _ ->
        assert_raise ChromicPDF.Browser.ExecutionError, ~r/Timeout in Channel.run_protocol/, fn ->
          # This print job is cancelled, i.e.
          # 1) the protocol is removed from the Channel
          # 2) the worker is terminated (exception handling of NimblePool), which closes the target
          # 3) a new worker is spawned
          print_to_pdf_delayed(30_000)
        end
      end)
    end
  end

  describe "failed worker checkout" do
    setup do
      # Setting the job timeout to 10s to be sure we run into the checkout error.
      start_supervised!({ChromicPDF, session_pool: [size: 1, timeout: 10_000]})

      :ok
    end

    test "generates a nice error message" do
      task = Task.async(fn -> print_to_pdf_delayed(7_000) end)

      # Wait for a little bit to make sure the task acquires the worker.
      :timer.sleep(300)

      assert_raise ChromicPDF.Browser.ExecutionError,
                   ~r/Caught EXIT signal from NimblePool/,
                   fn ->
                     print_to_pdf()
                   end

      # Ensure the other print succeeds as otherwise we'll receive a DOWN message in the
      # SessionPool.terminate_worker/3 callback.
      Task.await(task)
    end
  end

  describe "external termination of client process" do
    @pool_size 1

    setup do
      start_supervised!({ChromicPDF, session_pool: [size: @pool_size]})

      :ok
    end

    test "respawns the target and generates a warning in the logs" do
      assert capture_log(fn ->
               assert_target_respawn(@pool_size, fn _ ->
                 # Not linked to test process.
                 pid = spawn(fn -> print_to_pdf_delayed(2_000) end)

                 # Wait a little bit so the process has checked out the session.
                 :timer.sleep(500)

                 # Exit the process with anything but :normal (will be ignored).
                 # If the process is e.g. a request handler process, it receives a :timeout message.
                 # :kill works, too.
                 Process.exit(pid, :boom)
               end)
             end) =~ ~r/ChromicPDF received a :DOWN message/
    end
  end

  describe "named session pools" do
    setup do
      start_supervised!(
        {ChromicPDF,
         session_pool: %{
           raise: [unhandled_runtime_exceptions: :raise],
           ignore: [unhandled_runtime_exceptions: :ignore]
         }}
      )

      :ok
    end

    test "raises a descriptive error when pool does not exist" do
      assert_raise ChromicPDF.Browser.ExecutionError, ~r/Could not find session pool/, fn ->
        print_to_pdf({:html, "test"})
      end
    end

    test "named pools can be configured with different session options" do
      print_to_pdf({:html, test_exception_html()}, session_pool: :ignore)

      assert_raise ChromicPDF.ChromeError, ~r/Unhandled exception/, fn ->
        print_to_pdf({:html, test_exception_html()}, session_pool: :raise)
      end
    end
  end

  describe "global options cascading into session pool options" do
    setup do
      start_supervised!(
        {ChromicPDF,
         unhandled_runtime_exceptions: :raise,
         session_pool: %{
           raise: [],
           ignore: [unhandled_runtime_exceptions: :ignore]
         }}
      )

      :ok
    end

    test "global options are propagated and can be overridden" do
      print_to_pdf({:html, test_exception_html()}, session_pool: :ignore)

      assert_raise ChromicPDF.ChromeError, ~r/Unhandled exception/, fn ->
        print_to_pdf({:html, test_exception_html()}, session_pool: :raise)
      end
    end
  end
end
