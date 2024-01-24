defmodule ChainSyncClient do
  @moduledoc """
  This module syncs with the tip of the chain, reads the next 3 blocks
  and then closes the connection with the server.

  Add this to your application's supervision tree like so:

  def start(_type, _args) do
    children = [
      {ChainSyncClient, url: "ws://..."},
    ]
    ...
  end
  """

  use Xogmios, :chain_sync

  def start_link(opts) do
    initial_state = [counter: 3]
    ### See examples below on how to sync
    ### from different points of the chain:
    # initial_state = [sync_from: :babbage]
    # initial_state = [
    #   sync_from: %{
    #     point: %{
    #       slot: 114_127_654,
    #       id: "b0ff1e2bfc326a7f7378694b1f2693233058032bfb2798be2992a0db8b143099"
    #     }
    #   }
    # ]
    opts = Keyword.merge(opts, initial_state)
    Xogmios.start_chain_sync_link(__MODULE__, opts)
  end

  @impl true
  def handle_block(block, %{counter: counter} = state) when counter > 1 do
    IO.puts("handle_block #{block["height"]}")
    {:ok, :next_block, %{state | counter: counter - 1}}
  end

  @impl true
  def handle_block(block, state) do
    IO.puts("final handle_block #{block["height"]}")
    {:ok, :close, state}
  end
end
