defmodule Xogmios.ClientExampleA do
  @moduledoc """
  This module syncs with the tip of the chain and reads blocks indefinitely
  """

  use Xogmios.ChainSync

  require Logger

  def start_link(opts),
    do: start_connection(opts)

  @impl true
  def handle_block(block, state) do
    Logger.info("#{__MODULE__} handle_block #{block["height"]}")
    {:ok, :next_block, state}
  end
end
