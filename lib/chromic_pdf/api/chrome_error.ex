defmodule ChromicPDF.ChromeError do
  @moduledoc """
  Exception in the communication with Chrome.
  """

  defexception [:error, :opts, :message]

  @impl true
  def message(%__MODULE__{error: error, opts: opts}) do
    """
    #{title_for_error(error)}

    #{hint_for_error(error, opts)}
    """
  end

  defp title_for_error({:evaluate, _error}) do
    "Exception in :evaluate expression"
  end

  defp title_for_error(error) do
    error
  end

  defp hint_for_error("net::ERR_INTERNET_DISCONNECTED", _opts) do
    """
    You are trying to navigate to a remote URL but Chrome is not able to establish a connection
    to the remote host. Please make sure that you have access to the internet and that Chrome is
    allowed to open a connection to the remote host by your firewall policy.

    In case you are running ChromicPDF in "offline mode" this error is to be expected.
    """
  end

  defp hint_for_error("net::ERR_CERT" <> _, _opts) do
    """
    You are trying to navigate to a remote URL via HTTPS and Chrome is not able to verify the
    remote host's SSL certificate. If the remote is a production system, please make sure its
    certificate is valid and has not expired.

    In case you are connecting to a development/test system with a self-signed certificate, you
    can disable certificate verification by passing the `:ignore_certificate_errors` flag.

        {ChromicPDF, ignore_certificate_errors: true}
    """
  end

  defp hint_for_error({:evaluate, error}, opts) do
    %{
      "exception" => %{"description" => description},
      "lineNumber" => line_number
    } = error

    %{expression: expression} = Keyword.fetch!(opts, :evaluate)

    """
    Exception:

    #{indent(description)}

    Evaluated expression:

    #{indent(expression, line_number)}
    """
  end

  defp hint_for_error(_other, _opts) do
    """
    Chrome has responded with the above error error while you were trying to print a PDF.
    """
  end

  defp indent(expression, line_number \\ nil) do
    expression
    |> String.trim()
    |> String.split("\n")
    |> Enum.with_index()
    |> Enum.map_join("\n", fn
      {line, ^line_number} -> "!!!   #{line}"
      {line, _line_number} -> "      #{line}"
    end)
  end
end
