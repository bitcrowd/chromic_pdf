# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.Protocol do
  @moduledoc false

  alias ChromicPDF.Connection.JsonRPC

  # A protocol is a sequence of JsonRPC calls and responses/notifications.
  #
  # * It is created for each client request.
  # * It's goal is to fulfill the client request.
  # * A protocol's `steps` queue is a list of functions. When it is empty, the protocol is done.
  # * Besides, a protocol has a `state` map of arbitrary values.

  @type message :: JsonRPC.message()
  @type dispatch :: (JsonRPC.call() -> JsonRPC.call_id())

  @type state :: map()
  @type error :: {:error, term()}
  @type step :: call_step() | await_step() | output_step()

  # A protocol knows three types of steps: calls, awaits, and output.
  # * The call step is a protocol call to send to the browser. Multiple call steps in sequence
  #   are executed sequentially until the next await step is found.
  # * Await steps are steps that try to match on messages received from the browser. When a
  #   message is matched, the await step is removed from the queue. Multiple await steps in
  #   sequence are matched **out of order** as messages from the browser are often received out
  #   of order as well, from different OS processes.
  # * The output step is a simple function executed at the end of a protocol to fetch the result
  #   of the operation from the state. The result is then passed to the client in the channel.
  #   If no output step exists, the protocol returns `:ok`.
  #   Output step has to be the last step of the protocol.

  @type call_fun :: (state(), dispatch() -> state() | error())
  @type call_step :: {:call, call_fun()}

  @type await_fun :: (state(), message() -> :no_match | {:match, state()} | error())
  @type await_step :: {:await, await_fun()}

  @type output_fun :: (state() -> any())
  @type output_step :: {:output, output_fun()}

  @type result :: :ok | {:ok, any()} | {:error, term()}

  @callback new(keyword()) :: __MODULE__.t()
  @callback new(JsonRPC.session_id(), keyword()) :: __MODULE__.t()

  @type t :: %__MODULE__{steps: [step()], state: state()}

  @enforce_keys [:steps, :state]
  defstruct [:steps, :state]

  @spec new([step()], state()) :: __MODULE__.t()
  def new(steps, initial_state \\ %{}) do
    %__MODULE__{steps: steps, state: initial_state}
  end

  # Runs protocol instructions until all done or await instruction reached.
  @spec run(__MODULE__.t(), dispatch()) :: {:await, __MODULE__.t()} | {:halt, result()}
  def run(%__MODULE__{state: {:error, error}}, _dispatch) do
    {:halt, {:error, error}}
  end

  def run(%__MODULE__{steps: []}, _dispatch), do: {:halt, :ok}

  def run(%__MODULE__{steps: [{:await, _fun} | _rest]} = protocol, _dispatch),
    do: {:await, protocol}

  def run(%__MODULE__{steps: [{:call, fun} | rest], state: state} = protocol, dispatch) do
    state = fun.(state, dispatch)
    run(%{protocol | steps: rest, state: state}, dispatch)
  end

  def run(%__MODULE__{steps: [{:output, output_fun}], state: state}, _dispatch) do
    {:halt, {:ok, output_fun.(state)}}
  end

  # Returns updated protocol if message could be matched, :no_match otherwise.
  @spec match_chrome_message(__MODULE__.t(), JsonRPC.message()) ::
          :no_match | {:match, __MODULE__.t()}
  def match_chrome_message(%__MODULE__{steps: steps, state: state} = protocol, msg) do
    {awaits, rest} = Enum.split_while(steps, fn {type, _fun} -> type == :await end)

    case do_match_chrome_message(awaits, [], state, msg) do
      :no_match -> :no_match
      {:error, error} -> {:match, %{protocol | state: {:error, error}}}
      {new_head, new_state} -> {:match, %{protocol | steps: new_head ++ rest, state: new_state}}
    end
  end

  defp do_match_chrome_message([], _acc, _state, _msg), do: :no_match

  defp do_match_chrome_message([{:await, fun} | rest], acc, state, msg) do
    case fun.(state, msg) do
      :no_match -> do_match_chrome_message(rest, acc ++ [{:await, fun}], state, msg)
      {:match, new_state} -> {acc ++ rest, new_state}
      {:error, error} -> {:error, error}
    end
  end

  defimpl Inspect do
    @filtered "[FILTERED]"

    @allowed_values %{
      steps: true,
      state: %{
        :capture_screenshot => %{
          "format" => true,
          "quality" => true,
          "clip" => true,
          "fromSurface" => true,
          "captureBeyondViewport" => true
        },
        :print_to_pdf => %{
          "landscape" => true,
          "displayHeaderFooter" => true,
          "printBackground" => true,
          "scale" => true,
          "paperWidth" => true,
          "paperHeight" => true,
          "marginTop" => true,
          "marginBottom" => true,
          "marginLeft" => true,
          "marginRight" => true,
          "pageRanges" => true,
          "preferCSSPageSize" => true
        },
        :source_type => true,
        "sessionId" => true,
        "targetId" => true,
        "frameId" => true,
        :last_call_id => true,
        :wait_for => true,
        :evaluate => true,
        :size => true,
        :init_timeout => true,
        :timeout => true,
        :offline => true,
        :disable_scripts => true,
        :max_session_uses => true,
        :session_pool => true,
        :no_sandbox => true,
        :discard_stderr => true,
        :chrome_args => true,
        :chrome_executable => true,
        :ignore_certificate_errors => true,
        :ghostscript_pool => true,
        :on_demand => true,
        :__protocol__ => true
      }
    }

    def inspect(%ChromicPDF.Protocol{} = protocol, opts) do
      protocol
      |> Map.from_struct()
      |> filter(@allowed_values)
      |> then(fn map -> struct!(ChromicPDF.Protocol, map) end)
      |> Inspect.Any.inspect(opts)
    end

    defp filter(map, allowed) when is_map(map) and is_map(allowed) do
      Map.new(map, fn {key, value} ->
        case Map.get(allowed, key) do
          nil -> {key, @filtered}
          true -> {key, value}
          nested when is_map(nested) -> {key, filter(value, nested)}
        end
      end)
    end
  end
end
