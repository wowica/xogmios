defmodule Xogmios.HTTPTest do
  use ExUnit.Case, async: true

  alias Xogmios.StateQuery.HTTP

  describe "Xogmios.HTTP convenience module" do
    test "send_query/2 returns epoch" do
      assert {:ok, result} = HTTP.send_query("http://localhost:1337", "epoch")

      assert result == 450
    end

    test "send_query/2 returns protocol parameters" do
      assert {:ok, result} = HTTP.send_query("http://localhost:1337", "protocolParameters")

      assert result["minFeeCoefficient"] == 44
      assert result["maxBlockBodySize"]["bytes"] == 90_112
    end

    test "send_query/2 returns era start" do
      assert {:ok, result} = HTTP.send_query("http://localhost:1337", "eraStart")

      assert result["time"] == "2017-09-23T21:44:51Z"
      assert result["slot"] == 0
      assert result["epoch"] == 0
    end

    test "send_query/3 with params returns UTXOs" do
      params = %{addresses: ["addr1_test"]}
      assert {:ok, result} = HTTP.send_query("http://localhost:1337", "utxo", params)

      assert is_list(result)
      assert length(result) == 1

      utxo = List.first(result)
      assert utxo["transaction"]["id"] == "def456"
      assert utxo["output"]["address"] == "addr1_test"
    end

    test "send_query/2 with network query" do
      assert {:ok, result} = HTTP.send_query("http://localhost:1337", "queryNetwork/blockHeight")

      assert result["quantity"] == 9_876_543
      assert result["unit"] == "block"
    end
  end

  describe "URL handling" do
    test "converts WebSocket URLs to HTTP" do
      ws_result = HTTP.send_query("ws://localhost:1337", "epoch")
      http_result = HTTP.send_query("http://localhost:1337", "epoch")

      assert ws_result == http_result
      assert {:ok, 450} = ws_result
    end

    test "handles URLs with trailing slashes" do
      assert {:ok, 450} = HTTP.send_query("http://localhost:1337/", "epoch")
    end

    test "converts wss to https" do
      assert {:ok, 450} = HTTP.send_query("wss://remote.example.com", "epoch")
    end
  end

  describe "error handling" do
    test "handles connection errors" do
      assert {:error, {:request_failed, _reason}} =
               HTTP.send_query("http://localhost:9999", "trigger_connection_error")
    end

    test "handles HTTP error status codes" do
      assert {:error, {:http_error, 500, _body}} =
               HTTP.send_query("http://localhost:1337", "trigger_http_error")
    end

    test "handles JSON-RPC errors" do
      assert {:error, %{"code" => -32_602, "message" => "Invalid params"}} =
               HTTP.send_query("http://localhost:1337", "trigger_jsonrpc_error")
    end

    test "handles JSON decode errors" do
      assert {:error, {:decode_error, _reason}} =
               HTTP.send_query("http://localhost:1337", "trigger_decode_error")
    end

    test "handles unexpected JSON response" do
      assert {:error, {:unexpected_response, unexpected}} =
               HTTP.send_query("http://localhost:1337", "trigger_unexpected_response")

      assert unexpected["method"] == "something"
    end

    test "handles build message error for invalid query name" do
      assert {:error, {:build_message_error, _error}} =
               HTTP.send_query("http://localhost:1337", "queryNetwork/invalid/too/many/parts")
    end
  end
end
