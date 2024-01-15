defmodule Xogmios.Connection do
  @moduledoc """
  This module implements the connection with the Ogmios Websocket server.
  """

  @start_messages %{
    chain_sync: Xogmios.ChainSync.Messages.next_block_start()
  }

  @spec start_messages() :: map()
  def start_messages, do: @start_messages

  defmacro __using__(ouroboros_protocol) do
    quote do
      @behaviour :websocket_client

      @name __MODULE__

      require Logger

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          shutdown: 5_000,
          restart: Keyword.get(opts, :restart, :transient),
          type: :worker
        }
      end

      def init([%{handler: handler}]) do
        # Logger.debug("Xogmios.ChainSync init")
        {:once, %{handler: handler}}
      end

      defoverridable init: 1

      def start_connection(opts),
        do: do_start_link(opts)

      def do_start_link(opts) do
        url = Keyword.fetch!(opts, :url)
        state = %{handler: __MODULE__}
        :websocket_client.start_link(url, __MODULE__, [state])
      end

      def onconnect(_arg0, state) do
        # Logger.debug("on connect")
        start_message = get_start_message()
        :websocket_client.cast(self(), {:text, get_start_message()})
        {:ok, state}
      end

      defp get_start_message do
        # Each mini-protocol (chain sync, local state query, etc.)
        # requires a different start message to begin communication
        # with the server
        protocol = unquote(ouroboros_protocol)
        Map.get(Xogmios.Connection.start_messages(), protocol)
      end

      def ondisconnect(_reason, state) do
        # Logger.debug("on disconnect")
        {:ok, state}
      end

      def websocket_handle({:text, raw_message}, _conn, state) do
        case Jason.decode(raw_message) do
          {:ok, message} ->
            handle_message(message, state)

          {:error, reason} ->
            Logger.warning("Error decoding message #{inspect(reason)}")
            {:ok, state}
        end
      end

      def websocket_handle(_message, _conn, state) do
        # Logger.debug("raw_message #{inspect(message)}")
        {:ok, state}
      end

      def websocket_info(_any, _arg1, state) do
        # Logger.info("websocket_info")
        {:ok, state}
      end

      def websocket_terminate(_arg0, _arg1, _state) do
        # Logger.info("websocket_terminate")
        :ok
      end
    end
  end
end
