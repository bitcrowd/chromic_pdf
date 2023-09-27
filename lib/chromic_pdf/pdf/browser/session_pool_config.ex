# SPDX-License-Identifier: Apache-2.0

defmodule ChromicPDF.Browser.SessionPoolConfig do
  @moduledoc false

  import ChromicPDF.Utils, only: [default_pool_size: 0]

  @default_timeout 5000
  @default_init_timeout 5000
  @default_close_timeout 1000
  @default_max_uses 1000

  @default_pool_name :default

  # Normalizes global :session_pool option (keywords for default pool or map of named pools) into
  # a list of supervisor ids and pool options as combined from globals and named pool overrides.
  @spec pools_from_config(keyword()) :: [{__MODULE__, keyword()}]
  def pools_from_config(config) do
    config
    |> extract_named_pools()
    |> merge_globals_and_put_defaults(config)
  end

  defp extract_named_pools(config) do
    case Keyword.get(config, :session_pool, []) do
      opts when is_list(opts) -> %{@default_pool_name => opts}
      named_pools when is_map(named_pools) -> named_pools
    end
  end

  defp merge_globals_and_put_defaults(named_pools, config) do
    for {name, opts} <- named_pools do
      merged =
        config
        |> Keyword.merge(opts)
        |> Keyword.put_new(:size, default_pool_size())
        |> Keyword.put_new(:timeout, @default_timeout)
        |> Keyword.put_new(:init_timeout, @default_init_timeout)
        |> Keyword.put_new(:close_timeout, @default_close_timeout)
        |> put_default_max_uses()
        |> Keyword.put_new(:offline, false)
        |> Keyword.put_new(:ignore_certificate_errors, false)
        |> Keyword.put_new(:unhandled_runtime_exceptions, :log)

      {name, merged}
    end
  end

  defp put_default_max_uses(config) do
    cond do
      Keyword.has_key?(config, :max_uses) ->
        config

      Keyword.has_key?(config, :max_session_uses) ->
        {max_session_uses, config} = Keyword.pop(config, :max_session_uses)

        IO.warn("""
        [ChromicPDF] :max_session_uses option is deprecated, change your config to:

            [session_pool: [max_uses: #{max_session_uses}]]
        """)

        Keyword.put(config, :max_uses, max_session_uses)

      true ->
        Keyword.put(config, :max_uses, @default_max_uses)
    end
  end

  # Returns the targeted session pool from a map of PDF job params or the default pool name.
  @spec pool_name_from_params(keyword()) :: atom()
  def pool_name_from_params(pdf_params) do
    Keyword.get(pdf_params, :session_pool, @default_pool_name)
  end
end
