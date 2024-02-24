defmodule Xogmios.TxSubmission.Messages do
  @moduledoc """
  This module contains messages for the Tx Submission protocol
  """

  alias Jason.DecodeError

  @doc """
  Submits signed transaction represented by given cbor argument
  """
  def submit_tx(cbor) do
    json = ~s"""
    {
      "jsonrpc": "2.0",
      "method": "submitTransaction",
      "params": {
          "transaction": {
            "cbor": "#{cbor}"
          }
      }
    }
    """

    validate_json!(json)
    json
  end

  def evaluate_tx(cbor) do
    json = ~s"""
    {
      "jsonrpc": "2.0",
      "method": "evaluateTransaction",
      "params": {
          "transaction": {
            "cbor": "#{cbor}"
          }
      }
    }
    """

    validate_json!(json)
    json
  end

  defp validate_json!(json) do
    case Jason.decode(json) do
      {:ok, _decoded} -> :ok
      {:error, %DecodeError{} = error} -> raise "Invalid JSON: #{inspect(error)}"
    end
  end
end
