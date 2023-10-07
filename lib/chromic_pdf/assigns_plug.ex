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

    @type url :: binary
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

    @doc false
    @spec start_agent_and_return_signed_url(url, assigns) :: url
    def start_agent_and_return_signed_url(url, assigns) do
      assigns_from =
        assigns
        |> start_agent_and_sign_pid()
        |> encode_url_token()

      append_query(url, %{assigns_from: assigns_from})
    end

    defp start_agent_and_sign_pid(assigns) do
      # Salt is used in the signature as well as a simple authorization method to stop requests
      # with old valid signatures from accessing an agent with reused pid.
      salt = :crypto.strong_rand_bytes(8)

      {:ok, pid} = Agent.start_link(fn -> {salt, assigns} end)

      token = Crypto.sign(@secret_key_base, salt, :erlang.term_to_binary(pid))

      {token, salt}
    end

    defp encode_url_token(token_and_salt) do
      {:v1, token_and_salt}
      |> :erlang.term_to_binary()
      |> Base.url_encode64()
    end

    defp append_query(url, query) do
      # Elixir 1.14 added URI.append_query/2. When we require Elixir >=1.14, we may change to:
      #
      #      url
      #      |> URI.parse()
      #      |> URI.append_query(URI.encode_query(query))
      #      |> URI.to_string()

      uri = URI.parse(url)

      query =
        (uri.query || "")
        |> URI.decode_query()
        |> Map.merge(query)
        |> URI.encode_query()

      uri
      |> Map.put(:query, query)
      |> URI.to_string()
    end

    @impl Plug
    def init(opts), do: opts

    @impl Plug
    def call(conn, opts) do
      case conn.query_params do
        %{"assigns_from" => assigns_from} ->
          assigns_from
          |> decode_url_token()
          |> verify_pid_and_fetch_from_agent()
          |> assign_all(conn)

        %Conn.Unfetched{} ->
          # Custom endpoints may not have the query params fetched.
          conn
          |> Conn.fetch_query_params()
          |> call(opts)
      end
    end

    defp decode_url_token(assigns_from) do
      {:v1, token_and_salt} =
        assigns_from
        |> Base.url_decode64!()
        |> Crypto.non_executable_binary_to_term([:safe])

      token_and_salt
    end

    defp verify_pid_and_fetch_from_agent({token, salt}) do
      {:ok, payload} = Crypto.verify(@secret_key_base, salt, token, max_age: @max_age)

      # No need to safely decode this as it was signed.
      pid = :erlang.binary_to_term(payload)

      # Likewise no need for secure_compare as authenticity is already established.
      {^salt, payload} = Agent.get(pid, & &1)

      # Prevent process accumulation in case the client process is reused.
      Agent.stop(pid)

      payload
    end

    defp assign_all(assigns, conn) do
      Enum.reduce(assigns, conn, fn {key, value}, conn ->
        assign(conn, key, value)
      end)
    end
  end
end
