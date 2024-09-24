defmodule Xogmios.HealthCheck do
  @moduledoc """
  Performs a health check against the Ogmios server's HTTP endpoint.
  Used primarily to determine if the underlying Cardano node is fully synced.
  """
  @spec run(url :: String.t()) :: :ok | {:error, String.t()}
  def run(ogmios_url) do
    url = parse_url(ogmios_url)

    # NOTE: Investigate if there's a better way to start these.
    :inets.start()
    :ssl.start()

    case :httpc.request(:get, {String.to_charlist(url), []}, [], []) do
      {:ok, {{_, status_code, _}, _headers, _body}} ->
        case status_code do
          200 -> :ok
          _ -> {:error, "Received status code: #{status_code}"}
        end

      {:error, reason} ->
        {:error, "Error: #{inspect(reason)}"}
    end
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
