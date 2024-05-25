defmodule Xogmios.ChainSync.Connection do
  @moduledoc """
  This module implements a connection with the Ogmios Websocket server
  for the Chain Synchronization protocol.
  """

  alias Xogmios.ChainSync.Messages

  defmacro __using__(_opts) do
    quote do
      @behaviour :websocket_client

      require Logger

      @name __MODULE__
      @reconnect_interval 5_000

      def child_spec(opts) do
        %{
          id: Keyword.get(opts, :id, __MODULE__),
          start: {__MODULE__, :start_link, [opts]},
          shutdown: 5_000,
          restart: Keyword.get(opts, :restart, :transient),
          type: :worker
        }
      end

      @impl true
      def init(state) do
        initial_state =
          state
          |> Enum.into(%{})
          |> Map.merge(%{handler: __MODULE__})

        {:reconnect, initial_state}
      end

      @impl true
      def onconnect(connection, state) do
        state = Map.put(state, :ws_pid, self())

        start_message = Messages.next_block_start()
        :websocket_client.cast(self(), {:text, start_message})
        send(state.notify_on_connect, {:connected, connection})

        case state.handler.handle_connect(state) do
          {:ok, new_state} ->
            {:ok, new_state}

          _ ->
            {:ok, state}
        end
      end

      @impl true
      def ondisconnect(reason, state) do
        case state.handler.handle_disconnect(reason, state) do
          {:ok, state} ->
            {:ok, state}

          {:reconnect, reconnect_interval_in_ms, new_state} ->
            {:reconnect, reconnect_interval_in_ms, new_state}
        end
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
      def websocket_info(_any, _arg1, state) do
        {:ok, state}
      end

      @impl true
      def websocket_terminate(_arg0, _arg1, _state) do
        :ok
      end
    end
  end
end
