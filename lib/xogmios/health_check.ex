defmodule Xogmios.HealthCheck do
  @moduledoc """
  Performs a health check against the Ogmios server's HTTP endpoint.
  Used primarily to determine if the underlying Cardano node is fully synced.
  """

  @http_client :httpc

  @spec run(url :: String.t()) :: :ok | {:error, String.t()}
  def run(ogmios_url) do
    url = parse_url(ogmios_url)

    case client().request(:get, {String.to_charlist(url), []}, [], []) do
      {:ok, {{_, status_code, _}, _headers, json_body}} ->
        case status_code do
          200 ->
            :ok

          202 ->
            response_body = Jason.decode!(json_body)

            progress =
              response_body["networkSynchronization"]
              |> Kernel.*(100)
              |> Float.round(4)

            {:incomplete, "Cardano Node not ready. Network sync progress at #{progress}%"}

          _error_status_code ->
            {:error,
             """
             Ogmios service error. Cardano Node not ready.
             """}
        end

      {:error, reason} ->
        {:error, "Error: #{inspect(reason)}"}
    end
  end

  defp client do
    # Xogmios.HealthCheck.HTTPClientMock is used on test runs
    Application.get_env(:xogmios, __MODULE__, [])
    |> Keyword.get(:http_client, @http_client)
  end

  defp parse_url(url) do
    url
    |> replace_protocol()
    |> append_health_path()
  end

  defp replace_protocol(url) do
    url
    |> String.replace_prefix("ws://", "http://")
    |> String.replace_prefix("wss://", "https://")
  end

  defp append_health_path(url) do
    uri = URI.parse(url)
    path = if uri.path in [nil, ""], do: "/health", else: uri.path <> "/health"
    URI.to_string(%{uri | path: path})
  end
end
