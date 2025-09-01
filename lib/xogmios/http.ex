defmodule Xogmios.HTTP do
  @moduledoc """
  Convenience module that provides access to all stateless HTTP APIs.

  This module serves as a unified entry point for users who want to use
  Xogmios in a stateless manner via HTTP instead of WebSocket connections.
  """
  alias Xogmios.StateQuery
  alias Xogmios.TxSubmission

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
    StateQuery.HTTP.send_query(base_url, query, params)
  end

  @doc """
  Evaluates the execution units of scripts in a transaction via HTTP.

  This function is stateless and doesn't require a running process.

  ## Examples

      iex> Xogmios.HTTP.evaluate_tx("http://localhost:1337", cbor_data)
      {:ok, %{"evaluation" => %{"script1" => %{"memory" => 1000, "steps" => 500}}}}
  """
  @spec evaluate_tx(String.t(), String.t()) :: {:ok, any()} | {:error, any()}
  def evaluate_tx(base_url, cbor) do
    TxSubmission.HTTP.evaluate_tx(base_url, cbor)
  end

  @doc """
  Submits a transaction via HTTP.

  This function is stateless and doesn't require a running process.

  ## Examples

      iex> Xogmios.HTTP.submit_tx("http://localhost:1337", cbor_data)
      {:ok, %{"transaction" => %{"id" => "abc123..."}}}
  """
  @spec submit_tx(String.t(), String.t()) :: {:ok, any()} | {:error, any()}
  def submit_tx(base_url, cbor) do
    TxSubmission.HTTP.submit_tx(base_url, cbor)
  end
end
