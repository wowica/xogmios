defmodule Xogmios.ClientExampleB do
  @moduledoc """
  This module syncs with the tip of the chain and reads the following 3 blocks
  """

  use Xogmios.ChainSync

  require Logger

  def start_link(opts),
    do: start_connection(opts)

  @impl true
  def init(_args) do
    {:ok, %{counter: 2}}
  end

  @impl true
  def handle_block(block, %{counter: counter} = state) when counter > 1 do
    Logger.info("#{__MODULE__} handle_block #{block["height"]}")
    new_state = Map.merge(state, %{counter: counter - 1})
    {:ok, :next_block, new_state}
  end

  @impl true
  def handle_block(block, state) do
    Logger.info("#{__MODULE__} final handle_block #{block["height"]}")
    {:ok, :close, state}
  end
end
