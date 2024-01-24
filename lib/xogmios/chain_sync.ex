defmodule Xogmios.ChainSync do
  @moduledoc """
  This module interfaces with the Chain Synchronization protocol.
  """

  alias Xogmios.ChainSync.Messages

  @callback handle_block(map(), any()) ::
              {:ok, :next_block, map()} | {:ok, map()} | {:ok, :close, map()}

  def start_link(client, opts) do
    {url, opts} = Keyword.pop(opts, :url)
    initial_state = Keyword.merge(opts, handler: client)
    :websocket_client.start_link(url, client, initial_state)
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour Xogmios.ChainSync

      use Xogmios.ChainSync.Connection

      require Logger

      def handle_message(%{"id" => "start"} = message, state) do
        %{
          "method" => "nextBlock",
          "result" => %{"direction" => "backward", "tip" => tip}
        } = message

        message =
          case state[:sync_from] do
            nil ->
              # No option passed, sync with current tip
              Messages.find_intersection(tip["slot"], tip["id"])

            %{point: point} ->
              # Sync with a specific point
              Messages.find_intersection(point.slot, point.id)

            cardano_era when cardano_era in [:origin, :byron] ->
              # Sync with origin
              Messages.find_origin()

            cardano_era when is_atom(cardano_era) ->
              # Sync with a particular era bound
              Messages.last_block_from(cardano_era)
          end

        {:reply, {:text, message}, state}
      end

      def handle_message(%{"method" => "findIntersection"}, state) do
        message = Messages.next_block()
        {:reply, {:text, message}, state}
      end

      def handle_message(
            %{"method" => "nextBlock", "result" => %{"direction" => "backward"}},
            state
          ) do
        message = Messages.next_block()
        {:reply, {:text, message}, state}
      end

      def handle_message(
            %{"method" => "nextBlock", "result" => %{"direction" => "forward"} = result},
            state
          ) do
        case state.handler.handle_block(result["block"], state) do
          {:ok, :next_block, new_state} ->
            message = Messages.next_block()
            {:reply, {:text, message}, new_state}

          {:ok, new_state} ->
            {:ok, new_state}

          {:ok, :close, new_state} ->
            {:close, "finished", new_state}

          response ->
            Logger.warning("Invalid response #{inspect(response)}")
        end
      end

      def handle_message({:text, message}, state) do
        {:close, state}
      end
    end
  end
end
