if Code.ensure_loaded?(Plug) and Code.ensure_loaded?(Plug.Crypto) do
  defmodule ChromicPDF.AssignsPlug do
    @moduledoc """
    This module implements an "assigns passing" mechanism between a `print_to_pdf/2` caller process
    and an internal endpoint.

    ## Usage

    On the caller side:

        ChromicPDF.print_to_pdf({:url, "http://localhost:4000/makepdf"}, assigns: %{hello: :world})

    In your endpoint:

        plug ChromicPDF.AssignsPlug

    The plug makes the assigns available in `conn.assigns` to be used in the HTML template.
    """

    @behaviour Plug

    import Plug.Conn, only: [assign: 3]
    alias Plug.{Conn, Crypto}

    @type assigns :: map

    # max age of a "session", i.e. time between print_to_pdf and incoming request from Chrome.
    # This needs to be greater than the time it takes from the `print_to_pdf/2` call to the
    # incoming request from chrome. Should be around queue wait time of the job + a constant bit
    # for the navigation & network. Could be made dependent on `checkout_timeout` at some point.
    # We just set it to a long value for now to get it out of the way.
    @max_age 600

    # "secret_key_base" is generated at compile-time which ties the running Chrome instance
    # to the compiled module. Potentially this loses requests at the edges when using
    # _external_ chrome instances (i.e.  accessed via TCP) in a clustered environment, or when
    # hot deploying the application. Waiting for this unlikely issue to arise before making this
    # configurable / persistent between builds.
    @secret_key_base :crypto.strong_rand_bytes(32)

    # Salt is irrelevant.
    @salt :crypto.strong_rand_bytes(8)

    @cookie "chromic_pdf_cookie"

    @doc false
    @spec start_agent_and_get_cookie(assigns) :: map
    def start_agent_and_get_cookie(assigns) do
      value =
        assigns
        |> start_agent()
        |> sign_and_encode()

      %{name: @cookie, value: value}
    end

    defp start_agent(assigns) do
      ref = make_ref()

      {:ok, pid} = Agent.start_link(fn -> {ref, assigns} end)

      {pid, ref}
    end

    defp sign_and_encode(value) do
      payload = :erlang.term_to_binary(value)

      signed = Crypto.sign(@secret_key_base, @salt, payload)

      {:v1, signed}
      |> :erlang.term_to_binary()
      |> Base.url_encode64()
    end

    @impl Plug
    def init(opts), do: opts

    @impl Plug
    def call(conn, opts) do
      case conn.req_cookies do
        %{@cookie => cookie} ->
          cookie
          |> decode_and_verify()
          |> fetch_from_agent()
          |> assign_all(conn)

        %Conn.Unfetched{} ->
          # Custom endpoints may not have the cookies fetched.
          conn
          |> Conn.fetch_cookies()
          |> call(opts)
      end
    end

    defp decode_and_verify(encoded) do
      {:v1, signed} =
        encoded
        |> Base.url_decode64!()
        |> Crypto.non_executable_binary_to_term([:safe])

      {:ok, payload} = Crypto.verify(@secret_key_base, @salt, signed, max_age: @max_age)

      # No need to safely decode this as it was signed.
      :erlang.binary_to_term(payload)
    end

    defp fetch_from_agent({pid, ref}) do
      # No need for secure_compare as authenticity is already established.
      {^ref, assigns} = Agent.get(pid, & &1)

      # Prevent process accumulation in case the client process is reused.
      Agent.stop(pid)

      assigns
    end

    defp assign_all(assigns, conn) do
      Enum.reduce(assigns, conn, fn {key, value}, conn ->
        assign(conn, key, value)
      end)
    end
  end
end
