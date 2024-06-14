defmodule XogmiosWatcher.MempoolClient do
  @moduledoc """
  This module prints transactions as they become available
  in the mempool
  """
  use Xogmios, :mempool

  def start_link(opts) do
    Xogmios.start_mempool_link(__MODULE__, opts)
  end

  @impl true
  def handle_acquired(%{"slot" => slot} = _snapshot, state) do
    IO.puts("Snapshot acquired at slot #{slot}")

    {:ok, :next_transaction, state}
  end

  @impl true
  def handle_transaction(transaction, state) do
    IO.puts("Transaction: #{transaction["id"]}")

    {:ok, :next_transaction, state}
  end

  # Synchronous calls
  def get_size(pid \\ __MODULE__) do
    Xogmios.Mempool.get_size(pid)
  end

  def has_tx?(pid \\ __MODULE__, tx_id) do
    Xogmios.Mempool.has_transaction?(pid, tx_id)
  end
end
