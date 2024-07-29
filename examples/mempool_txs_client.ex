defmodule Xogmios.MempoolTxsClient do
  @moduledoc """
  This module prints transactions as they become available
  in the mempool.
  """
  use Xogmios, :mempool_txs

  def start_link(opts) do
    # set include_details: true to retrieve
    # complete information about the transaction.
    # set include_details: false (default) to retrieve
    # only transaction id.
    opts = Keyword.merge(opts, include_details: true)
    Xogmios.start_mempool_link(__MODULE__, opts)
  end

  @impl true
  def handle_transaction(transaction, state) do
    IO.puts("transaction #{inspect(transaction)}")

    {:ok, :next_transaction, state}
  end
end
