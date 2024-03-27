defmodule Xogmios.StateQuery.Server do
  @moduledoc false
  # This module implements the callbacks necessary for receiving asynchronous responses from
  # the WebSocket server. It acts as an synchronous interface for clients of Xogmios.StateQuery.
  # It uses GenServer.reply/2 to respond to GenServer.call/2 calls from Xogmios.StateQuery.send_query/2.

  @behaviour :websocket_client

  require Logger

  alias Xogmios.StateQuery.Messages
  alias Xogmios.StateQuery.Response

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
  def init(args) do
    # websocket_client.init/1 behaviour expects keyword list as argument
    # but maps are easier to work with downstream.
    initial_state = args |> Keyword.merge(caller: nil) |> Enum.into(%{})

    {:once, initial_state}
  end

  @impl true
  def onconnect(connection, state) do
    send(state.notify_on_connect, {:connected, connection})
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
