defmodule Xogmios.StateQuery.Messages do
  @moduledoc """
  This module returns messages for the State Query protocol
  """

  @doc """
  Returns point to be used by acquire_ledger_state/1
  """
  def get_tip do
    ~S"""
    {
      "jsonrpc": "2.0",
      "method": "queryNetwork/tip"
    }
    """
  end

  @doc """
  Acquires ledger state to be used by subsequent queries
  """
  def acquire_ledger_state(%{"slot" => slot, "id" => id} = _point) do
    ~s"""
    {
      "jsonrpc": "2.0",
      "method": "acquireLedgerState",
      "params": {
          "point": {
              "slot": #{slot},
              "id": "#{id}"
          }
      }
    }
    """
  end

  @doc """
  Returns current epoch
  """
  def get_current_epoch do
    ~S"""
    {
      "jsonrpc": "2.0",
      "method": "queryLedgerState/epoch"
    }
    """
  end
end
