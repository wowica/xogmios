defmodule Xogmios.HTTPTest do
  use ExUnit.Case, async: true

  alias Xogmios.HTTP
  alias Xogmios.StateQuery
  alias Xogmios.TxSubmission

  describe "Xogmios.HTTP convenience module - State Query" do
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

  describe "Xogmios.HTTP convenience module - Transaction Submission" do
    test "submit_tx/2 returns transaction result" do
      cbor = "84a400818258201234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef00"

      assert {:ok, result} = HTTP.submit_tx("http://localhost:1337", cbor)

      assert result["transaction"]["id"] ==
               "abc123def456789abcdef123456789abcdef123456789abcdef123456789abcdef"
    end

    test "evaluate_tx/2 returns evaluation result" do
      cbor = "84a400818258201234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef00"

      assert {:ok, result} = HTTP.evaluate_tx("http://localhost:1337", cbor)
      assert result["evaluation"]["spend:0"]["memory"] == 1_200_000
      assert result["evaluation"]["spend:0"]["steps"] == 500_000_000
    end
  end

  describe "Xogmios.StateQuery.HTTP direct module" do
    test "send_query/2 with simple query" do
      assert {:ok, result} = StateQuery.HTTP.send_query("http://localhost:1337", "epoch")
      assert result == 450
    end

    test "send_query/3 with parameters" do
      params = %{addresses: ["addr1_test"]}
      assert {:ok, result} = StateQuery.HTTP.send_query("http://localhost:1337", "utxo", params)

      assert is_list(result)
      assert length(result) == 1
    end

    test "send_query/2 with network scope query" do
      assert {:ok, result} =
               StateQuery.HTTP.send_query("http://localhost:1337", "queryNetwork/blockHeight")

      assert result["quantity"] == 9_876_543
    end
  end

  describe "Xogmios.TxSubmission.HTTP direct module" do
    test "submit_tx/2 with valid CBOR" do
      cbor = "84a400818258201234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef00"

      assert {:ok, result} = TxSubmission.HTTP.submit_tx("http://localhost:1337", cbor)

      assert result["transaction"]["id"] ==
               "abc123def456789abcdef123456789abcdef123456789abcdef123456789abcdef"
    end

    test "evaluate_tx/2 with valid CBOR" do
      cbor = "84a400818258201234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef00"

      assert {:ok, result} = TxSubmission.HTTP.evaluate_tx("http://localhost:1337", cbor)
      assert result["evaluation"]["spend:0"]["memory"] == 1_200_000
      assert result["evaluation"]["spend:0"]["steps"] == 500_000_000
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

    test "URL conversion works for transaction submission" do
      cbor = "84a400818258201234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef00"

      ws_result = HTTP.submit_tx("ws://localhost:1337", cbor)
      http_result = HTTP.submit_tx("http://localhost:1337", cbor)

      assert ws_result == http_result
    end
  end

  describe "error handling - State Query" do
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

  describe "error handling - Transaction Submission" do
    test "handles invalid CBOR error" do
      assert {:error, %{"code" => -32_600, "message" => message}} =
               HTTP.submit_tx("http://localhost:1337", "invalid_cbor")

      assert String.contains?(message, "failed to decode base16-encoded payload")
    end

    test "handles already in ledger error" do
      assert {:error, %{"code" => 3118, "message" => "The transaction is already in the ledger."}} =
               HTTP.submit_tx("http://localhost:1337", "already_in_ledger")
    end

    test "handles unknown UTxO references error" do
      assert {:error, %{"code" => 3117, "message" => message, "data" => data}} =
               HTTP.submit_tx("http://localhost:1337", "unknown_utxo")

      assert String.contains?(message, "unknown UTxO references")
      assert data["unknownOutputReferences"] |> length() == 1
    end

    test "handles missing signatures error" do
      assert {:error,
              %{"code" => 3101, "message" => "Some signatures are missing.", "data" => data}} =
               HTTP.submit_tx("http://localhost:1337", "trigger_submit_error")

      assert data["missingSignatories"] == ["abc123"]
    end

    test "handles script evaluation error" do
      assert {:error, %{"code" => 3102, "message" => "Script evaluation failed.", "data" => data}} =
               HTTP.evaluate_tx("http://localhost:1337", "trigger_evaluate_error")

      assert [%{"validator" => "abc123", "error" => "execution budget exceeded"}] =
               data["scriptFailures"]
    end

    test "handles connection errors for transaction submission" do
      assert {:error, {:request_failed, _reason}} =
               HTTP.submit_tx("http://localhost:9999", "trigger_connection_error")
    end

    test "handles HTTP error status codes for transaction submission" do
      assert {:error, {:http_error, 500, _body}} =
               HTTP.submit_tx("http://localhost:1337", "trigger_http_error")
    end

    test "handles JSON decode errors for transaction submission" do
      assert {:error, {:decode_error, _reason}} =
               HTTP.submit_tx("http://localhost:1337", "trigger_decode_error")
    end

    test "handles unexpected JSON response for transaction submission" do
      assert {:error, {:unexpected_response, unexpected}} =
               HTTP.submit_tx("http://localhost:1337", "trigger_unexpected_response")

      assert unexpected["method"] == "something"
    end

    test "handles connection errors for transaction evaluation" do
      assert {:error, {:request_failed, _reason}} =
               HTTP.evaluate_tx("http://localhost:9999", "trigger_connection_error")
    end

    test "handles HTTP error status codes for transaction evaluation" do
      assert {:error, {:http_error, 500, _body}} =
               HTTP.evaluate_tx("http://localhost:1337", "trigger_http_error")
    end
  end

  describe "transaction types" do
    test "handles simple payment transaction" do
      cbor = "84a400818258201234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef00"

      assert {:ok, result} = HTTP.submit_tx("http://localhost:1337", cbor)
      assert result["transaction"]["id"]
    end

    test "handles transaction evaluation with no scripts" do
      cbor = "84a400818258201234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef00"

      assert {:ok, result} = HTTP.evaluate_tx("http://localhost:1337", cbor)
      assert result["evaluation"]["spend:0"]
    end

    test "handles empty CBOR string" do
      assert {:error, %{"code" => -32_600}} = HTTP.submit_tx("http://localhost:1337", "")
    end

    test "handles malformed CBOR" do
      assert {:error, %{"code" => -32_600}} = HTTP.submit_tx("http://localhost:1337", "not_hex")
    end
  end
end
