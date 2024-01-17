defmodule Xogmios do
  @moduledoc """
  This is the top level module for Xogmios
  """

  alias Xogmios.ChainSync
  alias Xogmios.StateQuery

  def start_state_link(client, opts) do
    StateQuery.start_link(client, opts)
  end

  def start_chain_sync_link(client, opts) do
    ChainSync.start_link(client, opts)
  end

  defmacro __using__(:state_query) do
    quote do
      use Xogmios.StateQuery
    end
  end

  defmacro __using__(:chain_sync) do
    quote do
      use Xogmios.ChainSync
    end
  end
end
