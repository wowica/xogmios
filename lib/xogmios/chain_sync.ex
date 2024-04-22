defmodule Xogmios.ChainSync do
  @moduledoc """
  This module interfaces with the Chain Synchronization protocol.
  """

  alias Xogmios.ChainSync.Messages

  require Logger

  @doc """
  Invoked when a new block is emitted. This callback is required.

  Returning `{:ok, :next_block, new_state}` will request the next block once
  it's made available.

  Returning `{:ok, new_state}` will not request anymore blocks. Typically used
  in conjunction with `find_next_block/1` when syncing from a particular point
  in the history of the chain.

  Returning `{:ok, :close, new_state}` will close the connection to the server.
  """
  @callback handle_block(block :: map(), state) ::
              {:ok, :next_block, new_state}
              | {:ok, new_state}
              | {:close, new_state}
            when state: term(), new_state: term()

  @doc """
  Invoked upon connecting to the server. This callback is optional.
  """
  @callback handle_connect(state) :: {:ok, new_state}
            when state: term(), new_state: term()

  @doc """
  Invoked upon disconnecting from the server. This callback is optional.

  Returning `{:ok, new_state}` will allow the connection to close.

  Returning `{:reconnect, interval_in_ms}` will attempt a reconnection after `interval_in_ms`
  """
  @callback handle_disconnect(reason :: String.t(), state) ::
              {:ok, new_state}
              | {:reconnect, interval_in_ms :: non_neg_integer(), new_state}
            when state: term(), new_state: term()

  # The keepalive option is used to maintain the connection active.
  # This is important because proxies might close idle connections after a few seconds.
  @keepalive_in_ms 5_000

  @doc """
  Starts a new Chain Sync process linked to the current process.

  This function should not be called directly, but rather via `Xogmios.start_chain_sync_link/2`
  """
  @spec start_link(module(), start_options :: Keyword.t()) :: {:ok, pid()} | {:error, term()}
  def start_link(client, opts) do
    {url, opts} = Keyword.pop(opts, :url)
    initial_state = Keyword.merge(opts, handler: client, notify_on_connect: self())

    ws_link =
      :websocket_client.start_link({:local, client}, url, client, initial_state,
        keepalive: @keepalive_in_ms
      )

    case ws_link do
      {:ok, ws_pid} ->
        # Blocks until the connection with the Ogmios server
        # is established or until timeout is reached.
        receive do
          {:connected, _connection} -> ws_link
        after
          _timeout = 5_000 ->
            Logger.warning("Timeout connecting to Ogmios server")
            send(ws_pid, :close)
            {:error, :connection_timeout}
        end

      {:error, _} = error ->
        Logger.warning("Error connecting with Ogmios server")
        error
    end
  end

  @doc """
  Issues a message for finding the next block.

  This function should be used when manually syncing from a particular point in
  the history of the chain.

  The result of calling this method must be handled by the `c:handle_block/2`
  callback
  """
  @spec find_next_block(pid()) :: {:ok, block :: map()} | :error
  def find_next_block(pid) do
    # hacky af but it does the job for now

    state = :sys.get_state(pid)

    {_c, %{ws_pid: ws_pid}} = state |> elem(1) |> elem(5)

    caller = self()

    :sys.replace_state(pid, fn current_state ->
      {:connected, {:context, req, transport, empty_list, ws, {module, client_info}, _, _, _}} =
        current_state

      updated_client_info = Map.put(client_info, :caller, caller)

      {:connected,
       {:context, req, transport, empty_list, ws, {module, updated_client_info}, "", true, 0}}
    end)

    next_block_message = Xogmios.ChainSync.Messages.next_block()
    :websocket_client.cast(ws_pid, {:text, next_block_message})

    receive do
      {:ok, next_block} -> {:ok, next_block}
    after
      5_000 -> :error
    end
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour Xogmios.ChainSync

      use Xogmios.ChainSync.Connection

      require Logger

      def handle_connect(state), do: {:ok, state}
      def handle_disconnect(_reason, state), do: {:ok, state}
      defoverridable handle_connect: 1, handle_disconnect: 2

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
        if caller = Map.get(state, :caller) do
          # Returns to sync caller
          send(caller, {:ok, result["block"]})
          {:ok, state}
        else
          case state.handler.handle_block(result["block"], state) do
            {:ok, :next_block, new_state} ->
              message = Messages.next_block()
              {:reply, {:text, message}, new_state}

            {:ok, new_state} ->
              {:ok, new_state}

            {:close, new_state} ->
              {:close, "finished", new_state}

            response ->
              Logger.warning("Invalid response #{inspect(response)}")
          end
        end
      end

      def handle_message({:text, message}, state) do
        {:close, state}
      end
    end
  end
end
