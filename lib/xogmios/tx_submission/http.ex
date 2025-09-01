defmodule Xogmios.TxSubmission.HTTP do
  @moduledoc """
  Stateless HTTP client for Tx Submission protocol.

  This module provides a simpler alternative to the WebSocket-based API
  for one-off transaction submissions without maintaining persistent connections.
  """

  alias Xogmios.TxSubmission.Messages
  alias Xogmios.TxSubmission.Response

  @http_client :httpc
  @request_timeout 30_000

  @doc """
  Submits a transaction via HTTP and returns a response including the transaction id.

  This function is stateless and doesn't require a running process.
  """
  def submit_tx(base_url, cbor) do
    url = parse_url(base_url)
    message = Messages.submit_tx(cbor)

    with {:ok, response_body} <- http_request(url, message),
         {:ok, %Response{} = response} <- parse_response(response_body) do
      {:ok, response.result}
    end
  end

  @doc """
  Evaluates the execution units of scripts present in a given transaction.

  This function is stateless and doesn't require a running process.
  """
  def evaluate_tx(base_url, cbor) do
    url = parse_url(base_url)
    message = Messages.evaluate_tx(cbor)

    with {:ok, response_body} <- http_request(url, message),
         {:ok, %Response{} = response} <- parse_response(response_body) do
      {:ok, response.result}
    end
  end

  defp parse_url(url) do
    url
    |> String.trim_trailing("/")
    |> replace_protocol()
  end

  defp replace_protocol(url) do
    url
    |> String.replace_prefix("ws://", "http://")
    |> String.replace_prefix("wss://", "https://")
  end

  defp http_request(url, message) do
    headers = [
      {~c"Content-Type", ~c"application/json"},
      {~c"Accept", ~c"application/json"}
    ]

    case client().request(
           :post,
           {String.to_charlist(url), headers, ~c"application/json", message},
           [timeout: @request_timeout],
           []
         ) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        {:ok, body}

      {:ok, {{_, status_code, _}, _headers, body}} ->
        {:error, {:http_error, status_code, body}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  defp parse_response(body) do
    case Jason.decode(body) do
      {:ok, %{"result" => result}} ->
        {:ok, %Response{result: result}}

      {:ok, %{"error" => error}} ->
        {:error, error}

      {:ok, unexpected} ->
        {:error, {:unexpected_response, unexpected}}

      {:error, reason} ->
        {:error, {:decode_error, reason}}
    end
  end

  defp client do
    Application.get_env(:xogmios, __MODULE__, [])
    |> Keyword.get(:http_client, @http_client)
  end
end
