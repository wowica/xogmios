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
   * StateQueryClient.send_query("eraStart")
   * StateQueryClient.send_query("queryNetwork/blockHeight")

  Not all queries are supported yet.
  """

  use Xogmios, :state_query
  alias Xogmios.StateQuery

  def start_link(opts) do
    Xogmios.start_state_link(__MODULE__, opts)
  end

  def get_current_epoch(pid \\ __MODULE__) do
    StateQuery.send_query(pid, "epoch")
  end

  def send_query(pid \\ __MODULE__, query_name) do
    StateQuery.send_query(pid, query_name)
  end
end
