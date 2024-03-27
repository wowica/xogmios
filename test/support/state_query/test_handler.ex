defmodule StateQuery.TestHandler do
  @moduledoc false

  require Logger

  @behaviour :cowboy_websocket
  @current_epoch 333

  @utxos_by_address_result [
    %{
      "address" => "addr_test1vp7yrmz5p6mdm3ph0a0jaxtk58hny3wseuw80fwql93huygczalde",
      "index" => 0,
      "transaction" => %{
        "id" => "52bdc2329dda37627a1a00414e4e7d44f8269cc8a076d8cc7131d86e9409d5f7"
      },
      "value" => %{"ada" => %{"lovelace" => 2_684_930_051}}
    },
    %{
      "address" => "addr_test1vp7yrmz5p6mdm3ph0a0jaxtk58hny3wseuw80fwql93huygczalde",
      "index" => 0,
      "transaction" => %{
        "id" => "6a3f281d0fcbdeb034d057c27bf90c368b1648defbc0a3b9e8e9a3e25b958268"
      },
      "value" => %{
        "5c1c752ea30af4197171e0dbd60a39e54c2794f38d36b220974a99c9" => %{
          "589dbcbfd6e367d4f0496a052a4cf22a0784eda97858654de703552b2a3a8c40" => 1
        },
        "7583d06245af520fe618bcf5f33a9adc891502182ea2404a9023dc00" => %{
          "14b18f2f93274fdb132e4cb331d01fe0b16f9bcd09ef004c0c7fd648f9a8cf2b" => 1
        },
        "ada" => %{"lovelace" => 2_519_653_089},
        "cd0aacd3202e52d72740de1bd6522712b1a90aa6f52dcb717528d628" => %{
          "fd0df6c82f0d6b547db805e43c216e2c36aaf618b0cced9f81861b4d0f516446" => 1
        }
      }
    }
  ]

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
      {:ok, %{"method" => "queryLedgerState/epoch"}} ->
        payload =
          Jason.encode!(%{
            "method" => "queryLedgerState/epoch",
            "result" => @current_epoch
          })

        {:reply, {:text, payload}, state}

      {:ok, %{"method" => "queryLedgerState/utxo"}} ->
        payload =
          Jason.encode!(%{
            "method" => "queryLedgerState/utxo",
            "result" => @utxos_by_address_result
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
