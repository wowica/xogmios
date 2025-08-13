defmodule HTTPClient do
  @moduledoc """
  This module demonstrates the stateless HTTP API for simple state query operations.

  Unlike the WebSocket examples (state_query_client.ex, chain_sync_client.ex),
  this doesn't require starting processes or managing supervision trees.
  """

  alias Xogmios.HTTP

  @doc """
  Get current epoch via HTTP (stateless)
  """
  def get_current_epoch(base_url \\ "http://localhost:1337") do
    HTTP.send_query(base_url, "epoch")
  end

  @doc """
  Get era start information via HTTP
  """
  def get_era_start(base_url \\ "http://localhost:1337") do
    HTTP.send_query(base_url, "eraStart")
  end

  @doc """
  Get current block height via HTTP
  """
  def get_block_height(base_url \\ "http://localhost:1337") do
    HTTP.send_query(base_url, "queryNetwork/blockHeight")
  end

  @doc """
  Get protocol parameters via HTTP
  """
  def get_protocol_parameters(base_url \\ "http://localhost:1337") do
    HTTP.send_query(base_url, "protocolParameters")
  end

  @doc """
  Get UTXOs for specific addresses via HTTP
  """
  def get_utxos_by_addresses(addresses, base_url \\ "http://localhost:1337") do
    HTTP.send_query(base_url, "utxo", %{addresses: addresses})
  end

  @doc """
  Demo function showing all HTTP state query operations
  """
  def demo(base_url \\ "http://localhost:1337") do
    IO.puts("Testing Xogmios HTTP State Queries at #{base_url}")
    IO.puts("")

    IO.puts("State Queries:")

    case get_current_epoch(base_url) do
      {:ok, epoch} -> IO.puts("Current epoch: #{epoch}")
      {:error, error} -> IO.puts("Epoch error: #{inspect(error)}")
    end

    case get_block_height(base_url) do
      {:ok, %{"quantity" => height, "unit" => unit}} ->
        IO.puts("Block height: #{height} #{unit}")

      {:ok, result} ->
        IO.puts("Block height: #{inspect(result)}")

      {:error, error} ->
        IO.puts("Block height error: #{inspect(error)}")
    end

    case get_era_start(base_url) do
      {:ok, era_start} -> IO.puts("Era start: #{inspect(era_start)}")
      {:error, error} -> IO.puts("Era start error: #{inspect(error)}")
    end

    case get_protocol_parameters(base_url) do
      {:ok, params} ->
        IO.puts("Protocol parameters loaded: #{map_size(params)} parameters")
        IO.puts("Max block size: #{get_in(params, ["maxBlockBodySize", "bytes"])} bytes")
        IO.puts("Min fee coefficient: #{params["minFeeCoefficient"]}")

      {:error, error} ->
        IO.puts("Protocol parameters error: #{inspect(error)}")
    end

    IO.puts("")
    IO.puts("Demo completed!")
  end
end
