defmodule ChainSync.TestHandler do
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
    current_counter = Process.get(:counter) || 1

    case Jason.decode(payload) do
      {:ok, %{"id" => "initial_sync"}} ->
        payload =
          Jason.encode!(%{
            "method" => "nextBlock",
            "result" => %{
              "direction" => "forward",
              "block" => %{"height" => 123},
              "tip" => %{"id" => "abc123", "slot" => 123}
            }
          })

        Process.put(:counter, current_counter + 1)
        {:reply, {:text, payload}, state}

      {:ok, %{"method" => "nextBlock"}} ->
        payload =
          if current_counter == 2 do
            Jason.encode!(%{
              "method" => "nextBlock",
              "result" => %{
                "direction" => "backward",
                "point" => %{"id" => "abc123", "slot" => 123}
              }
            })
          else
            Jason.encode!(%{
              "method" => "nextBlock",
              "result" => %{
                "direction" => "forward",
                "block" => %{"height" => 456},
                "tip" => %{"id" => "abc123", "slot" => 123}
              }
            })
          end

        Process.put(:counter, current_counter + 1)

        {:reply, {:text, payload}, state}
    end
  end

  @impl true
  def websocket_handle(_message, state) do
    {:ok, state}
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
