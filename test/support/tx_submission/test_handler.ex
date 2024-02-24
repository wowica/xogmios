defmodule TxSubmission.TestHandler do
  @moduledoc false

  require Logger

  @behaviour :cowboy_websocket

  @impl true
  def init(request, state) do
    {:cowboy_websocket, request, state}
  end

  @impl true
  def websocket_init(state) do
    {:ok, state}
  end

  @valid_cbor_value %{
    "method" => "submitTransaction",
    "params" => %{"transaction" => %{"cbor" => "valid-cbor-value"}}
  }

  @invalid_cbor_value %{
    "method" => "submitTransaction",
    "params" => %{"transaction" => %{"cbor" => "invalid-cbor-value"}}
  }

  @valid_tx_evaluation_cbor %{
    "method" => "evaluateTransaction",
    "params" => %{"transaction" => %{"cbor" => "valid-cbor-value"}}
  }

  @impl true
  # Sends response back to client
  def websocket_handle({:text, payload}, state) do
    case Jason.decode(payload) do
      {:ok, @valid_cbor_value} ->
        payload =
          Jason.encode!(%{
            "method" => "submitTransaction",
            "result" => %{
              "transaction" => %{
                "id" => "ec7eea18fffca5395943c37671068f3621d7041ffa1c24e4f88bf579290fbc62"
              }
            }
          })

        {:reply, {:text, payload}, state}

      {:ok, @invalid_cbor_value} ->
        # Actual error returned from a malformed CBOR
        payload =
          Jason.encode!(%{
            "error" => %{
              "code" => -32_602,
              "data" => %{
                "allegra" =>
                  "invalid or incomplete value of type 'Transaction': Size mismatch when decoding Object / Array. Expected 3, but found 4.",
                "alonzo" =>
                  "invalid or incomplete value of type 'Transaction': expected list len or indef",
                "babbage" =>
                  "invalid or incomplete value of type 'Transaction': Failed to decode AuxiliaryData",
                "conway" =>
                  "invalid or incomplete value of type 'Transaction': Failed to decode AuxiliaryData",
                "mary" =>
                  "invalid or incomplete value of type 'Transaction': Size mismatch when decoding Object / Array. Expected 3, but found 4.",
                "shelley" =>
                  "invalid or incomplete value of type 'Transaction': Size mismatch when decoding Object / Array. Expected 3, but found 4."
              },
              "message" =>
                "Invalid transaction; It looks like the given transaction wasn't well-formed. Note that I try to decode the transaction in every possible era and it was malformed in ALL eras. Yet, I can't pinpoint the exact issue for I do not know in which era / format you intended the transaction to be. The 'data' field, therefore, contains errors for each era."
            },
            "id" => nil,
            "jsonrpc" => "2.0",
            "method" => "submitTransaction"
          })

        {:reply, {:text, payload}, state}

      {:ok, @valid_tx_evaluation_cbor} ->
        payload =
          Jason.encode!(%{
            "method" => "evaluateTransaction",
            "result" => [
              %{
                "budget" => %{"cpu" => 18_563_120, "memory" => 54_404},
                "validator" => %{"index" => 0, "purpose" => "spend"}
              }
            ]
          })

        {:reply, {:text, payload}, state}

      result ->
        Logger.error("Did not match #{inspect(result)}")
        {:reply, {:text, payload}, state}
    end
  end

  @impl true
  def terminate(_arg1, _arg2, _arg3) do
    :ok
  end

  @impl true
  def websocket_info(:stop, state) do
    {:stop, state}
  end

  @impl true
  def websocket_info(_message, state) do
    {:stop, state}
  end
end
