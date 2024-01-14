defmodule ChainSyncClient do
  @moduledoc """
  This module syncs with the tip of the chain and reads blocks indefinitely
  """

  use Xogmios.ChainSync

  ## Client API

  def start_link(opts),
    do: start_connection(opts)

  ## Callback

  @impl true
  def handle_block(block, state) do
    IO.puts("handle_block #{block["height"]}")
    {:ok, :next_block, state}
  end
end
