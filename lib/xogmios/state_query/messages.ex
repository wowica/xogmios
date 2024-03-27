defmodule Xogmios.StateQuery.Messages do
  @moduledoc """
  This module contains messages for the State Query protocol
  """

  alias Jason.DecodeError

  @doc """
  Builds a message for a given scope, method and parameters.

  * The scope can be either `"networkQuery"` or `"queryLedgerState"`.
  * The method can be any of the supported methods from [Network](https://ogmios.dev/mini-protocols/local-state-query/#network) or
  [Ledger-state](https://ogmios.dev/mini-protocols/local-state-query/#ledger-state) scopes.
  * Parameters are optional, according to the method in question.
  """
  @spec build_message(String.t(), String.t(), map()) :: String.t()

  # Builds a message for a method with no parameters
  def build_message(scope, name, %{} = _no_params) do
    json = ~s"""
    {
      "jsonrpc": "2.0",
      "method": "#{scope}/#{name}"
    }
    """

    validate_json!(json)
    json
  end

  # Builds a message for a method with parameters
  def build_message(scope, name, params) do
    params = Jason.encode!(params)

    json = ~s"""
    {
      "jsonrpc": "2.0",
      "method": "#{scope}/#{name}",
      "params": #{params}
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
