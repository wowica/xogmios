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
      {"trigger_http_error", :trigger_http_error},
      {"trigger_jsonrpc_error", :trigger_jsonrpc_error},
      {"trigger_connection_error", :trigger_connection_error},
      {"trigger_decode_error", :trigger_decode_error},
      {"trigger_unexpected_response", :trigger_unexpected_response},
      {"trigger_submit_error", :trigger_submit_error},
      {"trigger_evaluate_error", :trigger_evaluate_error},
      {"invalid_cbor", :invalid_cbor},
      {"already_in_ledger", :already_in_ledger},
      {"unknown_utxo", :unknown_utxo},
      {"not_hex", :invalid_cbor},
      {"\"\"", :empty_cbor},
      {"submitTransaction", :submit_tx},
      {"evaluateTransaction", :evaluate_tx},
      {"epoch", :epoch},
      {"blockHeight", :block_height},
      {"protocolParameters", :protocol_parameters},
      {"utxo", :utxo},
      {"eraStart", :era_start}
    ]

    keywords
    |> Enum.find_value(:default, fn {keyword, type} ->
      if String.contains?(body, keyword), do: type
    end)
  end

  defp build_response(:submit_tx), do: success_response(submit_tx_response())
  defp build_response(:evaluate_tx), do: success_response(evaluate_tx_response())
  defp build_response(:trigger_submit_error), do: success_response(submit_error_response())
  defp build_response(:trigger_evaluate_error), do: success_response(evaluate_error_response())
  defp build_response(:invalid_cbor), do: success_response(invalid_cbor_error())
  defp build_response(:empty_cbor), do: success_response(invalid_cbor_error())
  defp build_response(:already_in_ledger), do: success_response(already_in_ledger_error())
  defp build_response(:unknown_utxo), do: success_response(unknown_utxo_error())

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

  defp submit_tx_response do
    ~s({"jsonrpc":"2.0","result":{"transaction":{"id":"abc123def456789abcdef123456789abcdef123456789abcdef123456789abcdef"}}})
  end

  defp evaluate_tx_response do
    ~s({"jsonrpc":"2.0","result":{"evaluation":{"spend:0":{"memory":1200000,"steps":500000000}}}})
  end

  defp submit_error_response do
    ~s({"jsonrpc":"2.0","error":{"code":3101,"message":"Some signatures are missing.","data":{"missingSignatories":["abc123"]}}})
  end

  defp evaluate_error_response do
    ~s({"jsonrpc":"2.0","error":{"code":3102,"message":"Script evaluation failed.","data":{"scriptFailures":[{"validator":"abc123","error":"execution budget exceeded"}]}}})
  end

  defp invalid_cbor_error do
    ~s({"jsonrpc":"2.0","error":{"code":-32600,"message":"Invalid request: failed to decode base16-encoded payload."}})
  end

  defp already_in_ledger_error do
    ~s({"jsonrpc":"2.0","error":{"code":3118,"message":"The transaction is already in the ledger.","data":{"transactionId":"def456"}}})
  end

  defp unknown_utxo_error do
    ~s({"jsonrpc":"2.0","error":{"code":3117,"message":"The transaction contains unknown UTxO references as inputs.","data":{"unknownOutputReferences":[{"transaction":{"id":"def456"},"index":0}]}}})
  end

  defp epoch_response, do: ~s({"jsonrpc":"2.0","result":450})

  defp block_height_response do
    ~s({"jsonrpc":"2.0","result":{"quantity":9876543,"unit":"block"}})
  end

  defp protocol_parameters_response do
    ~s({"jsonrpc":"2.0","result":{"minFeeCoefficient":44,"maxBlockBodySize":{"bytes":90112},"minUtxoDepositConstant":{"ada":{"lovelace":0}}}})
  end

  defp utxo_response do
    ~s({"jsonrpc":"2.0","result":[{"transaction":{"id":"def456"},"output":{"address":"addr1_test","value":{"ada":{"lovelace":2000000}}}}]})
  end

  defp era_start_response do
    ~s({"jsonrpc":"2.0","result":{"time":"2017-09-23T21:44:51Z","slot":0,"epoch":0}})
  end

  defp jsonrpc_error_response do
    ~s({"jsonrpc":"2.0","error":{"code":-32602,"message":"Invalid params"}})
  end

  defp invalid_json_response, do: ~s({"jsonrpc":"2.0","result":invalid_json})

  defp unexpected_response, do: ~s({"jsonrpc":"2.0","id":"test","method":"something"})

  defp default_response, do: ~s({"jsonrpc":"2.0","result":"default_response"})
end
