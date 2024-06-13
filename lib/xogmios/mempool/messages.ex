defmodule Xogmios.Mempool.Messages do
  @moduledoc """
  This module contains messages for the Mempool protocol
  """

  alias Jason.DecodeError

  def acquire_mempool() do
    json = ~S"""
    {
      "jsonrpc": "2.0",
      "method": "acquireMempool"
    }
    """

    validate_json!(json)
    json
  end

  def next_transaction(include_details \\ false) do
    json =
      if include_details do
        ~S"""
        {
          "jsonrpc": "2.0",
          "method": "nextTransaction",
          "params": {
            "fields": "all"
          }
        }
        """
      else
        ~S"""
        {
          "jsonrpc": "2.0",
          "method": "nextTransaction",
          "params": {}
        }
        """
      end

    validate_json!(json)
    json
  end

  def size_of_mempool() do
    json = ~S"""
    {
      "jsonrpc": "2.0",
      "method": "sizeOfMempool"
    }
    """

    validate_json!(json)
    json
  end

  def has_transaction(tx_id) do
    json = ~s"""
    {
      "jsonrpc": "2.0",
      "method": "hasTransaction",
      "params": {
        "id": "#{tx_id}"
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
