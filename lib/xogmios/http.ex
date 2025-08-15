defmodule Xogmios.HTTP do
  @moduledoc """
  Convenience module that provides access to all stateless HTTP APIs.

  This module serves as a unified entry point for users who want to use
  Xogmios in a stateless manner via HTTP instead of WebSocket connections.
  """
  alias Xogmios.StateQuery.HTTP

  @doc """
  Sends a state query via HTTP.

  This function is stateless and doesn't require a running process.

  ## Examples

      iex> Xogmios.HTTP.send_query("http://localhost:1337", "epoch")
      {:ok, 450}

      iex> Xogmios.HTTP.send_query("http://localhost:1337", "utxo", %{addresses: ["addr1..."]})
      {:ok, [%{"transaction" => %{...}, "output" => %{...}}]}
  """
  @spec send_query(String.t(), String.t(), map()) :: {:ok, term()} | {:error, term()}
  def send_query(base_url, query, params \\ %{}) do
    HTTP.send_query(base_url, query, params)
  end
end
