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

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          shutdown: 5_000,
          restart: Keyword.get(opts, :restart, :transient),
          type: :worker
        }
      end

      def start_connection(opts),
        do: do_start_link(opts)

      def do_start_link(opts) do
        url = Keyword.fetch!(opts, :url)
        state = %{handler: __MODULE__}
        :websocket_client.start_link(url, __MODULE__, [state])
      end

      @impl true
      def init([%{handler: handler}]) do
        {:once, %{handler: handler}}
      end

      @impl true
      def onconnect(_arg, state) do
        start_message = Messages.next_block_start()
        :websocket_client.cast(self(), {:text, start_message})
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
