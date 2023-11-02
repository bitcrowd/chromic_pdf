if Code.ensure_loaded?(Plug) and Code.ensure_loaded?(Plug.Crypto) do
  defmodule ChromicPDF.Plug do
    @moduledoc """
    This module implements a "request forwarding" mechanism from an internal endpoint serving
    incoming requests by Chrome to the `print_to_pdf/2` caller process.

    ## Usage

    In your router:

        forward "/makepdf", ChromicPDF.Plug

    On the caller side:

        ChromicPDF.print_to_pdf(
          {:plug,
            url: "http://localhost:4000/makepdf",
            forward: {MyTemplate, :render, [%{hello: :world}]
          }
        )

        defmodule MyTemplate do
          def render(conn, assigns) do
            # send response via conn (and return conn) or return content to be sent by the plug
          end
        end
    """

    defmodule MissingCookieError do
      @moduledoc false
      defexception [:message, plug_status: 403]
    end

    defmodule InvalidCookieError do
      @moduledoc false
      defexception [:message, plug_status: 403]
    end

    @behaviour Plug

    import ChromicPDF.Utils, only: [rendered_to_iodata: 1]
    alias Plug.{Conn, Crypto}

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
    @spec start_agent_and_get_cookie(keyword) :: map
    def start_agent_and_get_cookie(job_opts) do
      value =
        job_opts
        |> start_agent()
        |> sign_and_encode()

      %{name: @cookie, value: value}
    end

    defp start_agent(job_opts) do
      ref = make_ref()

      {:ok, pid} = Agent.start_link(fn -> {ref, job_opts} end)

      :erlang.term_to_binary({pid, ref})
    end

    defp sign_and_encode(token) do
      signed = Crypto.sign(@secret_key_base, @salt, token)

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
          |> forward(conn)

        %Conn.Unfetched{} ->
          # Custom endpoints may not have the cookies fetched.
          conn
          |> Conn.fetch_cookies()
          |> call(opts)

        _ ->
          raise MissingCookieError
      end
    end

    defp decode_and_verify(encoded) do
      with {:ok, binary} <- Base.url_decode64(encoded),
           {:ok, term} <- safe_binary_to_term(binary),
           {:v1, signed} <- term,
           {:ok, token} <- Crypto.verify(@secret_key_base, @salt, signed, max_age: @max_age) do
        token
      else
        _ ->
          raise InvalidCookieError, "cookie was invalid or contained invalid or expired signature"
      end
    end

    defp safe_binary_to_term(binary) do
      {:ok, Crypto.non_executable_binary_to_term(binary, [:safe])}
    rescue
      ArgumentError -> :error
    end

    defp fetch_from_agent(token) do
      # No need to safely decode this as it was signed.
      {pid, ref} = :erlang.binary_to_term(token)

      # Likewise, no need for secure_compare as authenticity is already established.
      {^ref, job_opts} = Agent.get(pid, & &1)

      # Prevent process accumulation in case the client process is reused.
      Agent.stop(pid)

      job_opts
    end

    defp forward(job_opts, conn) do
      job_opts
      |> Keyword.fetch!(:forward)
      |> do_forward(conn)
      |> case do
        %Conn{} = conn ->
          conn

        value ->
          conn
          |> Conn.put_resp_content_type("text/html")
          |> Conn.send_resp(200, rendered_to_iodata(value))
      end
    end

    defp do_forward(f, conn) when is_function(f) do
      f.(conn)
    end

    defp do_forward({m, f, a}, conn) when is_atom(m) and is_atom(f) and is_list(a) do
      apply(m, f, [conn | a])
    end
  end
end
