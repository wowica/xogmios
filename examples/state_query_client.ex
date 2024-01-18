defmodule StateQueryClient do
  @moduledoc """
  This module queries against the known tip of the chain.

  Add this to your application's supervision tree like so:

  def start(_type, _args) do
    children = [
      {StateQueryClient, url: "ws://..."},
    ]
    ...
  end

  Then invoke functions:
   * StateQueryClient.get_current_epoch()
   * StateQueryClient.get_era_start()
   * StateQueryClient.get_bananas() # Returns error message

  Not all queries are supported yet.
  """

  use Xogmios, :state_query
  alias Xogmios.StateQuery

  @spec start_link(keyword()) :: {:ok, pid()} | {:error, any()}
  def start_link(opts) do
    Xogmios.start_state_link(__MODULE__, opts)
  end

  @spec get_current_epoch(pid() | atom()) :: {:ok, map()} | {:error, map()}
  def get_current_epoch(pid \\ __MODULE__) do
    StateQuery.send_query(pid, :get_current_epoch)
  end

  @spec get_era_start(pid() | atom()) :: {:ok, map()} | {:error, map()}
  def get_era_start(pid \\ __MODULE__) do
    StateQuery.send_query(pid, :get_era_start)
  end
end
