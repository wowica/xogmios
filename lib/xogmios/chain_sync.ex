defmodule Xogmios.ChainSync do
  alias Xogmios.ChainSync.Messages

  require Logger

  @callback handle_block(map(), any()) ::
              {:ok, :next_block, map()} | {:ok, map()} | {:ok, :close, map()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Xogmios.ChainSync
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

      def init([%{handler: handler}]) do
        Logger.debug("Xogmios.ChainSync init")
        {:once, %{handler: handler}}
      end

      defoverridable init: 1

      def start_connection(opts),
        do: do_start_link(opts)

      def do_start_link(opts) do
        url = Keyword.get(opts, :url, "ws://192.168.1.11:1339")
        state = %{handler: __MODULE__}
        IO.inspect("state: #{inspect(state)}")
        :websocket_client.start_link(url, __MODULE__, [state])
      end

      def onconnect(_arg0, state) do
        Logger.debug("on connect")
        message = Messages.next_block_start()
        :websocket_client.cast(self(), {:text, message})
        {:ok, state}
      end

      def start_sync(pid) do
        message = Messages.next_block_start()
        :websocket_client.cast(pid, {:text, message})
      end

      def ondisconnect(_reason, state) do
        Logger.debug("on disconnect")
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

      def handle_message(%{"id" => "start"} = message, state) do
        %{
          "method" => "nextBlock",
          "result" => %{"direction" => "backward", "tip" => tip}
        } = message

        Logger.debug("id start")
        message = Messages.find_intersection(tip["slot"], tip["id"])
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
        Logger.info("handle_block #{result["block"]["height"]}")

        case state.handler.handle_block(result["block"], state) do
          {:ok, :next_block, new_state} ->
            message = Messages.next_block()
            {:reply, {:text, message}, new_state}

          {:ok, new_state} ->
            {:ok, new_state}

          {:ok, :close, new_state} ->
            {:close, new_state}

          response ->
            Logger.warning("Invalid response #{inspect(response)}")
        end
      end

      def handle_message({:text, message}, state) do
        Logger.info("fallback handle message #{inspect(message)}")
        {:close, state}
      end

      def websocket_info(_any, _arg1, state) do
        Logger.info("websocket_info")
        {:ok, state}
      end

      def websocket_terminate(_arg0, _arg1, _state) do
        Logger.info("websocket_terminate")
        :ok
      end
    end
  end
end

# cast(Client, Frame) ->
#   gen_statem:cast(Client, {cast_frame, Frame}).

# send(Client, Frame) ->
#   gen_statem:call(Client, {send, Frame}).
