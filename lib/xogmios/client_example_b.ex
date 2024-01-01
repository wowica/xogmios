defmodule Xogmios.ClientExampleB do
  @moduledoc """
  This module syncs with the tip of the chain and reads the following 3 blocks
  """

  use Xogmios.ChainSync

  def start_link(opts),
    do: start_connection(opts)

  @impl true
  def init(_args) do
    {:ok, %{counter: 3}}
  end

  @impl true
  def handle_block(block, %{counter: counter} = state) when counter > 1 do
    IO.puts("#{__MODULE__} handle_block #{block["height"]}")
    new_state = Map.merge(state, %{counter: counter - 1})
    {:ok, :next_block, new_state}
  end

  @impl true
  def handle_block(block, state) do
    IO.puts("#{__MODULE__} final handle_block #{block["height"]}")
    {:ok, state}
  end
end
