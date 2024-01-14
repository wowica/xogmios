defmodule Xogmios.StateQuery do
  @moduledoc """
  This module defines the behaviour for StateQuery clients.
  """

  alias Xogmios.StateQuery.Messages

  @allowed_queries [:get_current_epoch, :get_era_start]

  @query_messages %{
    get_current_epoch: Messages.get_current_epoch(),
    get_era_start: Messages.get_era_start()
  }

  @method_queries %{
    "queryLedgerState/epoch" => :get_current_epoch,
    "queryLedgerState/eraStart" => :get_era_start
  }

  @callback init(keyword()) :: {:ok, map()}
  @callback handle_query_response(map(), any()) :: {:ok, map()} | {:ok, :close, map()}

  @spec allowed_queries() :: list()
  def allowed_queries, do: @allowed_queries

  @spec query_messages() :: map()
  def query_messages, do: @query_messages

  @spec method_queries() :: map()
  def method_queries, do: @method_queries

  defmacro __using__(_opts) do
    quote do
      @behaviour Xogmios.StateQuery

      use Xogmios.Connection, :state_query

      require Logger

      def send_query(query) do
        message = Map.get(Xogmios.StateQuery.query_messages(), query)

        if message do
          send_frame(__MODULE__, message)
        else
          Logger.warning("Invalid query #{query}")
        end
      end

      defp handle_message(
             %{"method" => "queryNetwork/tip"} = message,
             state
           ) do
        point = message["result"]
        message = Messages.acquire_ledger_state(point)
        {:reply, {:text, message}, state}
      end

      defp handle_message(
             %{"method" => "acquireLedgerState"} = message,
             state
           ) do
        {:ok, state}
      end

      defp handle_message(
             %{"method" => method, "result" => result} = _message,
             state
           ) do
        response =
          %{
            result: result,
            query: Map.get(Xogmios.StateQuery.method_queries(), method)
          }

        case apply(__MODULE__, :handle_query_response, [response, state]) do
          {:ok, new_state} ->
            {:ok, new_state}

          {:ok, :close, new_state} ->
            Logger.debug("Closing with new state")
            {:close, new_state}

          _ ->
            Logger.warning("Invalid client callback response")
        end
      end

      defp handle_message(message, state) do
        Logger.warning("uncaught message: #{inspect(message)}")
        {:ok, state}
      end
    end
  end
end
