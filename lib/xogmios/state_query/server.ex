defmodule Xogmios.StateQuery.Server do
  @moduledoc """
  This module implements the callbacks necessary for receiving asynchronous responses from
  the WebSocket server. It acts as an synchronous interface for clients of Xogmios.StateQuery.
  It uses GenServer.reply/2 to respond to GenServer.call/2 calls from Xogmios.StateQuery.send_query/2.
  """

  @behaviour :websocket_client

  require Logger

  alias Xogmios.StateQuery.Messages
  alias Xogmios.StateQuery.Response

  defp handle_message(
         %{"method" => "queryNetwork/tip"} = message,
         state
       ) do
    point = message["result"]
    message = Messages.acquire_ledger_state(point)
    {:reply, {:text, message}, state}
  end

  defp handle_message(
         %{"method" => "acquireLedgerState"} = _message,
         state
       ) do
    {:ok, state}
  end

  defp handle_message(
         %{"method" => _method, "result" => result},
         state
       ) do
    GenServer.reply(state.caller, {:ok, %Response{result: result}})
    {:ok, state}
  end

  defp handle_message(_message, state) do
    {:ok, state}
  end

  @impl true
  def init(_args) do
    {:once, %{caller: nil}}
  end

  @impl true
  def onconnect(_arg0, state) do
    start_message = Xogmios.StateQuery.Messages.get_tip()
    :websocket_client.cast(self(), {:text, start_message})
    {:ok, state}
  end

  @impl true
  def ondisconnect(_reason, state) do
    {:ok, state}
  end

  @impl true
  def websocket_handle({:text, raw_message}, _conn, state) do
    case Jason.decode(raw_message) do
      {:ok, message} ->
        handle_message(message, state)

      {:error, reason} ->
        Logger.warning("Error decoding message #{inspect(reason)}")
        {:ok, state}
    end
  end

  @impl true
  def websocket_handle(_message, _conn, state) do
    {:ok, state}
  end

  @impl true
  def websocket_info({:store_caller, caller}, _req, state) do
    # Stores caller of the query so that GenServer.reply knows
    # who to return the response to
    {:ok, %{state | caller: caller}}
  end

  @impl true
  def websocket_info(_any, _arg1, state) do
    {:ok, state}
  end

  @impl true
  def websocket_terminate(_arg0, _arg1, _state) do
    :ok
  end
end
