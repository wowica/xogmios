defmodule Xogmios.StateQuery.HTTP do
  @moduledoc """
  Stateless HTTP client for State Query protocol.

  This module provides a simpler alternative to the WebSocket-based API
  for one-off queries without maintaining persistent connections.
  """

  alias Xogmios.StateQuery.Messages
  alias Xogmios.StateQuery.Response

  @http_client :httpc
  @request_timeout 30_000
  @valid_scopes ["queryNetwork", "queryLedgerState"]

  @doc """
  Sends a State Query via HTTP and returns a response.

  This function is stateless and doesn't require a running process.

  Support for all [Ledger-state](https://ogmios.dev/mini-protocols/local-state-query/#ledger-state)
  and [Network](https://ogmios.dev/mini-protocols/local-state-query/#network) queries.

  For Ledger-state queries, only the name of the query is needed. For example:
  - `send_query(url, "epoch")` is the same as `send_query(url, "queryLedgerState/epoch")`

  For Network queries, the prefix "queryNetwork/" is needed:
  - `send_query(url, "queryNetwork/blockHeight")`
  """
  def send_query(base_url, query, params \\ %{}) do
    url = parse_url(base_url)

    with {:ok, message} <- build_query_message(query, params),
         {:ok, response_body} <- http_request(url, message),
         {:ok, %Response{} = response} <- parse_response(response_body) do
      {:ok, response.result}
    end
  end

  defp build_query_message(query_name, query_params) do
    try do
      {scope, name} = parse_query_name(query_name)
      message = Messages.build_message(scope, name, query_params)
      {:ok, message}
    rescue
      error -> {:error, {:build_message_error, error}}
    end
  end

  defp parse_query_name(query_name) do
    case String.split(query_name, "/") do
      [scope, name] when scope in @valid_scopes -> {scope, name}
      [name] -> {"queryLedgerState", name}
      _ -> raise ArgumentError, "Invalid query name: #{query_name}"
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
