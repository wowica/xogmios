defmodule Xogmios.ChainSync do
  @moduledoc """
  This module interfaces with the Chain Synchronization protocol.
  """

  alias Xogmios.ChainSync.Messages

  require Logger

  @doc """
  Invoked when a new block is emitted. This callback is required.

  Receives block information as argument and the current state of the handler.

  Returning `{:ok, :next_block, new_state}` will request the next block once
  it's made available.

  Returning `{:ok, new_state}` will not request anymore blocks.

  Returning `{:close, new_state}` will close the connection to the server.
  """
  @callback handle_block(block :: map(), state) ::
              {:ok, :next_block, new_state}
              | {:ok, new_state}
              | {:close, new_state}
            when state: term(), new_state: term()

  @doc """
  Invoked when a rollback event is emitted. This callback is optional.

  Receives as argument a point and the state of the handler. The point is a
  map with keys for `id` (block id) and a `slot`. This information can then
  be used by the handler module to perform the necessary corrections.
  For example, resetting all current known state past this point and then
  rewriting it from future invokations of `c:handle_block/2`

  Returning `{:ok, :next_block, new_state}` will request the next block once
  it's made available.

  Returning `{:ok, new_state}` will not request anymore blocks.

  Returning `{:close, new_state}` will close the connection to the server.
  """
  @callback handle_rollback(point :: map(), state) ::
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

  # The websocket client library
  @client :websocket_client

  @doc """
  Starts a new Chain Sync process linked to the current process.

  This function should not be called directly, but rather via `Xogmios.start_chain_sync_link/2`
  """
  @spec start_link(module(), start_options :: Keyword.t()) :: {:ok, pid()} | {:error, term()}
  def start_link(client, opts) do
    {url, opts} = Keyword.pop(opts, :url)
    {name, opts} = Keyword.pop(opts, :name, client)
    initial_state = Keyword.merge(opts, handler: client, notify_on_connect: self())

    with {:ok, process_name} <- build_process_name(name),
         {:ok, ws_pid} <- start_link(process_name, url, client, initial_state) do
      # Blocks until the connection with the Ogmios server
      # is established or until timeout is reached.
      receive do
        {:connected, _connection} -> {:ok, ws_pid}
      after
        _timeout = 5_000 ->
          Logger.warning("Timeout connecting to Ogmios server")
          send(ws_pid, :close)
          {:error, :connection_timeout}
      end
    else
      {:error, :invalid_process_name} = error ->
        error

      {:error, _} = error ->
        Logger.warning("Error connecting with Ogmios server #{inspect(error)}")
        error
    end
  end

  defp start_link(name, url, client, state) do
    @client.start_link(name, url, client, state, keepalive: @keepalive_in_ms)
  end

  # Builds process name from valid argument or returns error
  @spec build_process_name(term() | {:global, term()} | {:via, term(), term()}) ::
          {:ok, any()} | {:error, term()}
  defp build_process_name(name) do
    case name do
      name when is_atom(name) ->
        {:ok, {:local, name}}

      {:global, term} = tuple when is_atom(term) ->
        {:ok, tuple}

      {:via, registry, _term} = tuple when is_atom(registry) ->
        {:ok, tuple}

      _ ->
        # Returns error if name does not comply with
        # values accepted by the websocket client library
        {:error, :invalid_process_name}
    end
  end

  @doc """
  > #### Warning {: .warning}
  >
  > This is a highly experimental function and should not be relied on just yet.

  Issues a synchronous message for reading the next block.
  Potentially useful for building chain indexers with support for backpressure mechanism.
  """
  @spec read_next_block(pid()) :: {:ok, block :: map()} | :error
  def read_next_block(pid) do
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
      def handle_rollback(_point, state), do: {:ok, :next_block, state}
      defoverridable handle_connect: 1, handle_disconnect: 2, handle_rollback: 2

      def handle_message(%{"id" => "initial_sync"} = message, state) do
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
        message = Messages.next_block_start()
        {:reply, {:text, message}, state}
      end

      # This function handles the initial and unique roll backward event as
      # part of finding and intersection.
      #
      #
      # From Ogmios' official docs:
      #
      # "After successfully finding an intersection, the node will always ask
      # to roll backward to that intersection point. This is because it is
      # possible to provide many points when looking for an intersection and
      # the protocol makes sure that both the node and the client are in sync.
      # This allows clients applications to be somewhat “dumb” and blindly
      # follow instructions from the node."
      def handle_message(
            %{
              "id" => "next_block_start",
              "method" => "nextBlock",
              "result" => %{"direction" => "backward"}
            } = message,
            state
          ) do
        message = Messages.next_block()
        {:reply, {:text, message}, state}
      end

      # This function handles rollbacks
      def handle_message(
            %{
              "method" => "nextBlock",
              "result" => %{"direction" => "backward"} = result
            },
            state
          ) do
        case state.handler.handle_rollback(result["point"], state) do
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
