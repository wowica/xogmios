defmodule Xogmios.StateQuery.Messages do
  @moduledoc """
  This module contains messages for the State Query protocol
  """

  alias Jason.DecodeError

  @doc """
  Returns point to be used by `acquire_ledger_state/1`
  """
  def get_tip do
    json = ~S"""
    {
      "jsonrpc": "2.0",
      "method": "queryNetwork/tip"
    }
    """

    validate_json!(json)
    json
  end

  @doc """
  Acquires ledger state to be used by subsequent queries
  """
  def acquire_ledger_state(%{"slot" => slot, "id" => id} = _point) do
    json = ~s"""
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

    validate_json!(json)
    json
  end

  def build_message(scope \\ "queryLedgerState", name) do
    json = ~s"""
    {
      "jsonrpc": "2.0",
      "method": "#{scope}/#{name}"
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
