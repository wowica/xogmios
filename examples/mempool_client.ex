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
  def handle_transaction(transaction, state) do
    IO.puts("transaction #{transaction["id"]}")

    {:ok, :next_transaction, state}
  end
end
