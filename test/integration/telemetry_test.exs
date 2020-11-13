defmodule ChromicPDF.TelemetryTest do
  use ExUnit.Case, async: false

  setup do
    start_supervised!(ChromicPDF)
    :ok
  end

  def handler(event, measurements, metadata, _config) do
    send(self(), %{
      event: event,
      measurements: measurements,
      metadata: metadata
    })
  end

  defp with_handler(event, fun) do
    :ok = :telemetry.attach("#{event}_start", [:chromic_pdf, event, :start], &handler/4, nil)
    :ok = :telemetry.attach("#{event}_stop", [:chromic_pdf, event, :stop], &handler/4, nil)

    try do
      fun.()
    after
      :ok = :telemetry.detach("#{event}_start")
      :ok = :telemetry.detach("#{event}_stop")
    end
  end

  defp assert_events(event, fun) do
    with_handler(event, fun)

    assert_receive %{
      event: [:chromic_pdf, ^event, :start],
      measurements: %{},
      metadata: %{foo: :bar}
    }

    assert_receive %{
      event: [:chromic_pdf, ^event, :stop],
      measurements: %{duration: _duration},
      metadata: %{foo: :bar}
    }
  end

  test "executes events for print_to_pdf/2" do
    assert_events(:print_to_pdf, fn ->
      {:ok, _blob} = ChromicPDF.print_to_pdf({:html, ""}, telemetry_metadata: %{foo: :bar})
    end)
  end

  test "executes events for capture_screenshot/2" do
    assert_events(:capture_screenshot, fn ->
      {:ok, _blob} = ChromicPDF.capture_screenshot({:html, ""}, telemetry_metadata: %{foo: :bar})
    end)
  end

  test "executes events for print_to_pdfa/2" do
    assert_events(:convert_to_pdfa, fn ->
      assert_events(:print_to_pdf, fn ->
        {:ok, _blob} = ChromicPDF.print_to_pdfa({:html, ""}, telemetry_metadata: %{foo: :bar})
      end)
    end)
  end

  test "executes events for convert_to_pdfa/2" do
    ChromicPDF.print_to_pdf({:html, ""},
      output: fn tmpfile ->
        assert_events(:convert_to_pdfa, fn ->
          {:ok, _blob} = ChromicPDF.convert_to_pdfa(tmpfile, telemetry_metadata: %{foo: :bar})
        end)
      end
    )
  end
end
