defmodule Xogmios.ChainSync.Connection do
  @moduledoc """
  This module implements a connection with the Ogmios Websocket server
  for the Chain Synchronization protocol.
  """
  require Logger

  alias Xogmios.HealthCheck
  alias Xogmios.ChainSync.Messages

  defmacro __using__(_opts) do
    quote do
      @behaviour :banana_websocket_client

      require Logger

      @name __MODULE__
      @reconnect_interval 5_000

      def child_spec(opts) do
        %{
          id: Keyword.get(opts, :id, __MODULE__),
          start: {__MODULE__, :start_link, [opts]},
          shutdown: 5_000,
          restart: Keyword.get(opts, :restart, :temporary),
          type: :worker
        }
      end

      defp send_initial_sync_message do
        start_message = Messages.initial_sync()
        :banana_websocket_client.cast(self(), {:text, start_message})
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

        with :ok <- HealthCheck.run(state.url),
             :ok <- send_initial_sync_message() do
          case state.handler.handle_connect(state) do
            {:ok, new_state} ->
              {:ok, new_state}

            _ ->
              {:ok, state}
          end
        else
          {:error, reason} ->
            Logger.error("""
            Ogmios reported error: #{reason}\
            Trying reconnection in 5 seconds.
            """)

            {:reconnect, 5_000, state}

          {:incomplete, reason} ->
            Logger.warning("""
            #{reason} \
            Trying reconnection in 5 seconds.
            """)

            {:reconnect, 5_000, state}
        end
      end

      @impl true
      def ondisconnect(reason, state) do
        case state.handler.handle_disconnect(reason, state) do
          # Attempt to reconnect after interval in ms
          {:reconnect, reconnect_interval_in_ms, new_state} ->
            {:reconnect, reconnect_interval_in_ms, new_state}

          # Shut the process down cleanly
          {:close, reason, state} ->
            {:close, reason, state}

          # Disconnect but keeps process alive
          {:ok, state} ->
            {:ok, state}
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
      def websocket_info(message, _conn, state) do
        if function_exported?(state.handler, :handle_info, 2) do
          case state.handler.handle_info(message, state) do
            {:ok, :next_block, new_state} ->
              message = Messages.next_block()
              {:reply, {:text, message}, new_state}

            {:ok, new_state} ->
              {:ok, new_state}

            {:close, new_state} ->
              {:close, "finished", new_state}

            response ->
              Logger.warning("Invalid response from handle_info: #{inspect(response)}")
              {:ok, state}
          end
        else
          Logger.warning("Unhandled info message #{inspect(message)}")
          {:ok, state}
        end
      end

      @impl true
      def websocket_terminate(_arg0, _arg1, _state) do
        :ok
      end
    end
  end
end
