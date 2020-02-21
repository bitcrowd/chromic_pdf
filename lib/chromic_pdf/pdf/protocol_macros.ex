defmodule ChromicPDF.ProtocolMacros do
  @moduledoc false

  defmacro steps(do: block) do
    quote do
      Module.register_attribute(__MODULE__, :steps, accumulate: true)

      unquote(block)

      defp build_steps(opts \\ []) do
        excludes = Keyword.get(opts, :exclude, [])

        @steps
        |> Enum.reverse()
        |> Enum.reject(fn {_, name, _arity} -> name in excludes end)
        |> Enum.map(fn {type, name, arity} ->
          {type, Function.capture(__MODULE__, name, arity)}
        end)
      end
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
          state =
            Enum.into(
              unquote(put_keys),
              state,
              &{&1, get_in(msg, ["result", &1])}
            )

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
          state =
            Enum.into(
              unquote(put_keys),
              state,
              &{&1, get_in(msg, ["params", &1])}
            )

          {:match, state}
        else
          _ -> :no_match
        end
      end
    end
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
