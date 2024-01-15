defmodule ChainSyncClient do
  @moduledoc """
  This module syncs with the tip of the chain and reads blocks indefinitely.

  Add this to your application's supervision tree like so:

  def start(_type, _args) do
    children = [
      {ChainSyncClient, url: "ws://..."},
    ]
    ...
  end
  """

  use Xogmios.ChainSync

  def start_link(opts),
    do: start_connection(opts)

  @impl true
  def handle_block(block, state) do
    IO.puts("handle_block from client #{block["height"]}")
    {:ok, :next_block, state}
  end
end
