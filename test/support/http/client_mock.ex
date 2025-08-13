defmodule Xogmios.HTTP.ClientMock do
  def request(:post, {_url, _headers, _content_type, body}, _options, []) do
    cond do
      String.contains?(body, "epoch") ->
        response_body = ~s({"jsonrpc":"2.0","result":450})
        {:ok, {{nil, 200, nil}, [], response_body}}

      String.contains?(body, "blockHeight") ->
        response_body = ~s({"jsonrpc":"2.0","result":{"quantity":9876543,"unit":"block"}})
        {:ok, {{nil, 200, nil}, [], response_body}}

      String.contains?(body, "protocolParameters") ->
        response_body =
          ~s({"jsonrpc":"2.0","result":{"minFeeCoefficient":44,"maxBlockBodySize":{"bytes":90112},"minUtxoDepositConstant":{"ada":{"lovelace":0}}}})

        {:ok, {{nil, 200, nil}, [], response_body}}

      String.contains?(body, "utxo") ->
        response_body =
          ~s({"jsonrpc":"2.0","result":[{"transaction":{"id":"def456"},"output":{"address":"addr1_test","value":{"ada":{"lovelace":2000000}}}}]})

        {:ok, {{nil, 200, nil}, [], response_body}}

      String.contains?(body, "eraStart") ->
        response_body =
          ~s({"jsonrpc":"2.0","result":{"time":"2017-09-23T21:44:51Z","slot":0,"epoch":0}})

        {:ok, {{nil, 200, nil}, [], response_body}}

      String.contains?(body, "trigger_http_error") ->
        response_body =
          ~s({"jsonrpc":"2.0","error":{"code":-32602,"message":"Invalid params"}})

        {:ok, {{nil, 500, nil}, [], response_body}}

      String.contains?(body, "trigger_jsonrpc_error") ->
        response_body =
          ~s({"jsonrpc":"2.0","error":{"code":-32602,"message":"Invalid params"}})

        {:ok, {{nil, 200, nil}, [], response_body}}

      String.contains?(body, "trigger_connection_error") ->
        {:error,
         {:failed_connect,
          [{:to_address, {~c"localhost", 9999}}, {:inet, [:inet], :econnrefused}]}}

      String.contains?(body, "trigger_decode_error") ->
        invalid_json = ~s({"jsonrpc":"2.0","result":invalid_json})
        {:ok, {{nil, 200, nil}, [], invalid_json}}

      String.contains?(body, "trigger_unexpected_response") ->
        unexpected_json = ~s({"jsonrpc":"2.0","id":"test","method":"something"})
        {:ok, {{nil, 200, nil}, [], unexpected_json}}

      true ->
        response_body = ~s({"jsonrpc":"2.0","result":"default_response"})
        {:ok, {{nil, 200, nil}, [], response_body}}
    end
  end
end
