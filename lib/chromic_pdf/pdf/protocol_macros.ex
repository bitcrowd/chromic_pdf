defmodule ChromicPDF.ProtocolMacros do
  @moduledoc false

  # credo:disable-for-next-line
  defmacro steps(do: block) do
    quote do
      alias ChromicPDF.{JsonRPC, Protocol}

      Module.register_attribute(__MODULE__, :steps, accumulate: true)

      unquote(block)

      @spec new(keyword()) :: Protocol.t()
      def new(opts) do
        Protocol.new(
          build_steps(opts),
          Enum.into(opts, %{})
        )
      end

      @spec new(JsonRPC.session_id(), keyword()) :: Protocol.t()
      def new(session_id, opts) do
        Protocol.new(
          build_steps(opts),
          opts |> Enum.into(%{}) |> Map.put("sessionId", session_id)
        )
      end

      defp build_steps(opts) do
        @steps
        |> Enum.reverse()
        |> do_build_steps([], opts)
        |> Enum.reverse()
      end

      defp do_build_steps([], acc, _opts), do: acc

      defp do_build_steps([:end | rest], acc, opts) do
        do_build_steps(rest, acc, opts)
      end

      defp do_build_steps([{:if_option, key, value} | rest], acc, opts) do
        if Keyword.get(opts, key) == value do
          do_build_steps(rest, acc, opts)
        else
          skip_branch(rest, acc, opts)
        end
      end

      defp do_build_steps([{type, name, arity} | rest], acc, opts) do
        do_build_steps(
          rest,
          [{type, Function.capture(__MODULE__, name, arity)} | acc],
          opts
        )
      end

      defp skip_branch([], acc, _opts), do: acc
      defp skip_branch([:end | rest], acc, opts), do: do_build_steps(rest, acc, opts)
      defp skip_branch([_skipped | rest], acc, opts), do: skip_branch(rest, acc, opts)
    end
  end

  defmacro if_option({test_key, test_value}, do: block) do
    quote do
      @steps {:if_option, unquote(test_key), unquote(test_value)}
      unquote(block)
      @steps :end
    end
  end

  defmacro call(name, method, params_from_state, default_params) do
    quote do
      @steps {:call, unquote(name), 2}
      def unquote(name)(state, dispatch) do
        params =
          fetch_params_for_call(
            state,
            unquote(params_from_state),
            unquote(default_params)
          )

        call_id =
          case Map.get(state, "sessionId") do
            nil -> dispatch.({unquote(method), params})
            session_id -> dispatch.({session_id, unquote(method), params})
          end

        Map.put(state, :last_call_id, call_id)
      end
    end
  end

  def fetch_params_for_call(state, fun, defaults) when is_function(fun, 1) do
    Map.merge(defaults, fun.(state))
  end

  def fetch_params_for_call(state, keys, defaults) when is_list(keys) do
    Enum.into(keys, defaults, &{&1, Map.fetch!(state, &1)})
  end

  defmacro await_response(name, put_keys) do
    quote do
      @steps {:await, unquote(name), 2}
      def unquote(name)(state, msg) do
        last_call_id = Map.fetch!(state, :last_call_id)

        if ChromicPDF.JsonRPC.is_response?(msg, last_call_id) do
          state = extract_from_payload(msg, "result", unquote(put_keys), state)

          {:match, state}
        else
          :no_match
        end
      end
    end
  end

  defmacro await_notification(name, method, match_keys, put_keys) do
    quote do
      @steps {:await, unquote(name), 2}
      def unquote(name)(state, msg) do
        with true <- ChromicPDF.JsonRPC.is_notification?(msg, unquote(method)),
             true <- state["sessionId"] == msg["sessionId"],
             true <- Enum.all?(unquote(match_keys), &notification_matches?(state, msg, &1)) do
          state = extract_from_payload(msg, "params", unquote(put_keys), state)

          {:match, state}
        else
          _ -> :no_match
        end
      end
    end
  end

  def extract_from_payload(msg, payload_key, put_keys, state) do
    Enum.into(
      put_keys,
      state,
      fn
        {path, key} -> {key, get_in(msg, [payload_key | path])}
        key -> {key, get_in(msg, [payload_key, key])}
      end
    )
  end

  def notification_matches?(state, msg, {msg_path, key}) do
    get_in(msg, ["params" | msg_path]) == Map.fetch!(state, key)
  end

  def notification_matches?(state, msg, key), do: notification_matches?(state, msg, {[key], key})

  defmacro reply(key) do
    quote do
      @steps {:reply, :reply, 1}
      def reply(state), do: Map.fetch!(state, unquote(key))
    end
  end
end
