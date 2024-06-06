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

  def next_transaction() do
    json = ~S"""
    {
      "jsonrpc": "2.0",
      "method": "nextTransaction",
      "params": {
        "fields": "all"
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
