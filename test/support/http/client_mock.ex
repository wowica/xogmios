defmodule Xogmios.HTTP.ClientMock do
  @moduledoc """
  Mock HTTP client for testing Xogmios JSON-RPC API interactions.

  This module provides a mock implementation of HTTP requests that simulates
  various responses from the Xogmios API, including successful responses for
  different query types and error conditions for testing error handling.
  """

  @doc """
  Handles mock HTTP POST requests based on request body content.

  Returns different responses based on keywords found in the request body.
  """
  def request(:post, {_url, _headers, _content_type, body}, _options, []) do
    body
    |> detect_request_type()
    |> build_response()
  end

  def request(method, _request, _options, _profile) do
    {:error, {:unsupported_method, method}}
  end

  defp detect_request_type(body) do
    keywords = [
      {"epoch", :epoch},
      {"blockHeight", :block_height},
      {"protocolParameters", :protocol_parameters},
      {"utxo", :utxo},
      {"eraStart", :era_start},
      {"trigger_http_error", :trigger_http_error},
      {"trigger_jsonrpc_error", :trigger_jsonrpc_error},
      {"trigger_connection_error", :trigger_connection_error},
      {"trigger_decode_error", :trigger_decode_error},
      {"trigger_unexpected_response", :trigger_unexpected_response}
    ]

    keywords
    |> Enum.find_value(:default, fn {keyword, type} ->
      if String.contains?(body, keyword), do: type
    end)
  end

  defp build_response(:epoch), do: success_response(epoch_response())
  defp build_response(:block_height), do: success_response(block_height_response())
  defp build_response(:protocol_parameters), do: success_response(protocol_parameters_response())
  defp build_response(:utxo), do: success_response(utxo_response())
  defp build_response(:era_start), do: success_response(era_start_response())
  defp build_response(:trigger_http_error), do: error_response(jsonrpc_error_response(), 500)
  defp build_response(:trigger_jsonrpc_error), do: success_response(jsonrpc_error_response())
  defp build_response(:trigger_connection_error), do: connection_error()
  defp build_response(:trigger_decode_error), do: success_response(invalid_json_response())
  defp build_response(:trigger_unexpected_response), do: success_response(unexpected_response())
  defp build_response(:default), do: success_response(default_response())

  defp success_response(body), do: {:ok, {{nil, 200, nil}, [], body}}
  defp error_response(body, status), do: {:ok, {{nil, status, nil}, [], body}}

  defp connection_error do
    {:error,
     {:failed_connect, [{:to_address, {~c"localhost", 9999}}, {:inet, [:inet], :econnrefused}]}}
  end

  defp epoch_response, do: ~s({"jsonrpc":"2.0","result":450})

  defp block_height_response,
    do: ~s({"jsonrpc":"2.0","result":{"quantity":9876543,"unit":"block"}})

  defp protocol_parameters_response do
    ~s({"jsonrpc":"2.0","result":{"minFeeCoefficient":44,"maxBlockBodySize":{"bytes":90112},"minUtxoDepositConstant":{"ada":{"lovelace":0}}}})
  end

  defp utxo_response do
    ~s({"jsonrpc":"2.0","result":[{"transaction":{"id":"def456"},"output":{"address":"addr1_test","value":{"ada":{"lovelace":2000000}}}}]})
  end

  defp era_start_response,
    do: ~s({"jsonrpc":"2.0","result":{"time":"2017-09-23T21:44:51Z","slot":0,"epoch":0}})

  defp jsonrpc_error_response,
    do: ~s({"jsonrpc":"2.0","error":{"code":-32602,"message":"Invalid params"}})

  defp invalid_json_response, do: ~s({"jsonrpc":"2.0","result":invalid_json})

  defp unexpected_response, do: ~s({"jsonrpc":"2.0","id":"test","method":"something"})

  defp default_response, do: ~s({"jsonrpc":"2.0","result":"default_response"})
end
