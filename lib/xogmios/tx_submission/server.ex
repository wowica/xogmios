defmodule Xogmios.TxSubmission.Server do
  @moduledoc false

  @behaviour :banana_websocket_client

  require Logger

  alias Xogmios.TxSubmission.Response

  defp handle_message(
         %{"method" => _method, "result" => result},
         state
       ) do
    GenServer.reply(state.caller, {:ok, %Response{result: result}})
    {:ok, state}
  end

  defp handle_message(%{"error" => error_info}, state) do
    GenServer.reply(state.caller, {:error, error_info})
    {:ok, state}
  end

  defp handle_message(message, state) do
    Logger.info("Unhandled message: #{inspect(message)}")
    {:ok, state}
  end

  @impl true
  def init(_args) do
    {:once, %{caller: nil}}
  end

  @impl true
  def onconnect(_arg0, state) do
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
