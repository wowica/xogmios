defmodule MempoolTxs.TestHandler do
  @moduledoc false

  @behaviour :cowboy_websocket

  @impl true
  def init(request, state) do
    {:cowboy_websocket, request, state}
  end

  @impl true
  def websocket_init(state) do
    {:ok, state}
  end

  @impl true
  def websocket_handle({:text, payload}, state) do
    case Jason.decode(payload) do
      {:ok, %{"method" => "acquireMempool"}} ->
        payload =
          Jason.encode!(%{
            "method" => "acquireMempool",
            "result" => %{"acquired" => "mempool", "slot" => 123}
          })

        {:reply, {:text, payload}, state}

      {:ok, %{"method" => "nextTransaction"}} ->
        payload =
          Jason.encode!(%{
            "method" => "nextTransaction",
            "result" => %{
              "transaction" => %{"id" => 456}
            }
          })

        {:reply, {:text, payload}, state}
    end
  end

  @impl true
  def terminate(_arg1, _arg2, _arg3) do
    :ok
  end

  def websocket_info(:stop, state) do
    {:stop, state}
  end

  @impl true
  def websocket_info(info, state) do
    {:reply, {:text, info}, state}
  end
end
