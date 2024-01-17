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

  def start_link(opts) do
    Xogmios.start_state_link(__MODULE__, opts)
  end

  def get_current_epoch() do
    case send_query(:get_current_epoch) do
      {:ok, result} -> result
      {:error, reason} -> "Something went wrong #{inspect(reason)}"
    end
  end

  def get_era_start() do
    case send_query(:get_era_start) do
      {:ok, result} -> result
      {:error, reason} -> "Something went wrong #{inspect(reason)}"
    end
  end

  def get_bananas() do
    case send_query(:get_bananas) do
      {:ok, result} -> result
      {:error, reason} -> "Something went wrong #{inspect(reason)}"
    end
  end
end
