defmodule Xogmios.ChainSync.Messages do
  @moduledoc """
  This module returns messages for the Chain Synchronization protocol
  """

  alias Jason.DecodeError

  def next_block_start() do
    json = ~S"""
    {
      "jsonrpc": "2.0",
      "method": "nextBlock",
      "id": "start"
    }
    """

    validate_json!(json)
    json
  end

  def next_block() do
    json = ~S"""
    {
      "jsonrpc": "2.0",
      "method": "nextBlock"
    }
    """

    validate_json!(json)
    json
  end

  def find_intersection(slot, id) do
    json = ~s"""
    {
      "jsonrpc": "2.0",
      "method": "findIntersection",
      "params": {
          "points": [
            {
              "slot": #{slot},
              "id": "#{id}"
            }
        ]
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
