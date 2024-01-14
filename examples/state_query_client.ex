defmodule StateQueryClient do
  @moduledoc """
  This module queries against the known tip of the chain
  """

  use Xogmios.StateQuery
  @allowed_queries Xogmios.StateQuery.allowed_queries()

  ## Client API

  def start_link(opts),
    do: start_connection(opts)

  def get_current_epoch(),
    do: send_query(:get_current_epoch)

  def get_era_start(),
    do: send_query(:get_era_start)

  ## Callback

  @impl true
  def handle_query_response(%{query: query, result: result}, state)
      when query in @allowed_queries do
    case query do
      :get_current_epoch ->
        IO.puts("Current epoch: #{result}")

      :get_era_start ->
        IO.puts("Era started on epoch #{result["epoch"]} and slot #{result["slot"]}")
    end

    {:ok, state}
  end
end
