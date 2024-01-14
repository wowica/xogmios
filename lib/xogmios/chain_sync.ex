defmodule Xogmios.ChainSync do
  @moduledoc """
  This module defines the behaviour for ChainSync clients.
  """

  alias Xogmios.ChainSync.Messages

  @callback init(keyword()) :: {:ok, map()}
  @callback handle_block(map(), any()) ::
              {:ok, :next_block, map()} | {:ok, map()} | {:ok, :close, map()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Xogmios.ChainSync

      use Xogmios.Connection, :chain_sync

      require Logger

      defp handle_message(
             %{
               "id" => "start",
               "method" => "nextBlock",
               "result" => %{"direction" => "backward", "tip" => tip} = _result
             } = _message,
             state
           ) do
        message = Messages.find_intersection(tip["slot"], tip["id"])
        {:reply, {:text, message}, state}
      end

      defp handle_message(
             %{"method" => "nextBlock", "result" => %{"direction" => "backward"}} = _message,
             state
           ) do
        message = Messages.next_block()
        {:reply, {:text, message}, state}
      end

      defp handle_message(
             %{"method" => "nextBlock", "result" => %{"direction" => "forward"} = result} =
               _message,
             state
           ) do
        block = result["block"]

        case apply(__MODULE__, :handle_block, [block, state]) do
          {:ok, :next_block, new_state} ->
            message = Messages.next_block()
            {:reply, {:text, message}, new_state}

          {:ok, new_state} ->
            {:ok, new_state}

          {:ok, :close, new_state} ->
            {:close, new_state}

          _ ->
            Logger.warning("Invalid return type")
        end
      end

      defp handle_message(%{"method" => "findIntersection"}, state) do
        message = Messages.next_block()
        {:reply, {:text, message}, state}
      end

      defp handle_message(message, state) do
        Logger.warning("uncaught message: #{inspect(message)}")
        {:ok, state}
      end
    end
  end
end
