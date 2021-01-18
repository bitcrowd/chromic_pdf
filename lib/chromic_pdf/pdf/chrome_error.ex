defmodule ChromicPDF.ChromeError do
  defexception [:code, :message]

  @impl true
  def message(%__MODULE__{code: code}) do
    """
    #{code}

    #{hint_for_code(code)}
    """
  end

  defp hint_for_code("net::ERR_INTERNET_DISCONNECTED") do
    """
    You are trying to navigate to a remote URL but Chrome is not able to establish a connection
    to the remote host. Please make sure that you have access to the internet and that Chrome is
    allowed to open a connection to the remote host by your firewall policy.

    In case you are running ChromicPDF in "offline mode" this error is to be expected.
    """
  end

  defp hint_for_code("net::ERR_CERT" <> _) do
    """
    You are trying to navigate to a remote URL via HTTPS and Chrome is not able to verify the
    remote host's SSL certificate. If the remote is a production system, please make sure its
    certificate is valid and has not expired.

    In case you are connecting to a development/test system with a self-signed certificate, you
    can disable certificate verification by passing the `:ignore_certificate_errors` flag.

        {ChromicPDF, ignore_certificate_errors: true}
    """
  end

  defp hint_for_code(_other) do
    """
    Chrome has responded with the above error code while you were trying to print a PDF.
    """
  end
end
