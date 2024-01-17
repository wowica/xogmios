defmodule StateQuery.TestHandler do
  @moduledoc false

  require Logger

  @behaviour :cowboy_websocket
  @current_epoch 333

  @impl true
  def init(request, state) do
    {:cowboy_websocket, request, state}
  end

  @impl true
  def websocket_init(state) do
    {:ok, state}
  end

  @impl true
  # Sends response back to client
  def websocket_handle({:text, payload}, state) do
    case Jason.decode(payload) do
      {:ok, %{"method" => "queryNetwork/tip"}} ->
        payload =
          Jason.encode!(%{
            "method" => "queryNetwork/tip",
            "result" => %{"slot" => "123", "id" => "123"}
          })

        {:reply, {:text, payload}, state}

      {:ok, %{"method" => "acquireLedgerState"}} ->
        payload =
          Jason.encode!(%{
            "method" => "acquireLedgerState"
          })

        {:reply, {:text, payload}, state}

      {:ok, %{"method" => "queryLedgerState/epoch"}} ->
        payload =
          Jason.encode!(%{
            "method" => "can-be-anything",
            "result" => @current_epoch
          })

        {:reply, {:text, payload}, state}

      result ->
        IO.puts("Did not match #{inspect(result)}")
        {:reply, {:text, payload}, state}
    end
  end

  @impl true
  def terminate(_arg1, _arg2, _arg3) do
    :ok
  end

  @impl true
  def websocket_info(:stop, state) do
    {:stop, state}
  end

  @impl true
  def websocket_info(_message, state) do
    {:stop, state}
  end
end
