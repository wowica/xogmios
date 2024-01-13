defmodule Xogmios.ChainSync.Messages do
  @moduledoc """
  This module returns messages for the Chain Synchronization protocol
  """

  def next_block_start() do
    ~S"""
    {
      "jsonrpc": "2.0",
      "method": "nextBlock",
      "id": "start"
    }
    """
  end

  def next_block() do
    ~S"""
    {
      "jsonrpc": "2.0",
      "method": "nextBlock"
    }
    """
  end

  def find_intersection(slot, id) do
    ~s"""
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
  end
end
