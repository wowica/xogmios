defmodule Xogmios.Mempool do
  @moduledoc """
  This module interfaces with the Mempool protocol.
  """

  alias Xogmios.Mempool.Messages

  require Logger

  @doc """
  Invoked when a new transaction is made available in the mempool.

  Receives transaction information as argument and current state of the handler.

  Returning `{:ok, :next_transaction, new_state}` will request the next transaction
  once it's made available.

  Returning `{:ok, new_state}` wil not request anymore transactions.

  Returning `{:close, new_state}` will close the connection to the server
  """
  @callback handle_transaction(transaction :: map(), state) ::
              {:ok, :next_transaction, new_state}
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
  Starts a new Mempool process linked to the current process.

  This function should not be called directly, but rather via `Xogmios.start_mempool_link/2`
  """
  @spec start_link(module(), start_options :: Keyword.t()) :: {:ok, pid()} | {:error, term()}
  def start_link(client, opts) do
    {url, opts} = Keyword.pop(opts, :url)
    {name, opts} = Keyword.pop(opts, :name, client)
    opts = Keyword.put_new(opts, :include_details, false)
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
  Issues a synchronous message for getting the size of the mempool.
  """
  @spec size_of_mempool(pid()) :: {:ok, response :: map()} | :error
  def size_of_mempool(pid) do
    # hacky af but it does the job for now
    ws_pid = update_ws_with_caller(pid)

    message = Xogmios.Mempool.Messages.size_of_mempool()
    :websocket_client.cast(ws_pid, {:text, message})

    receive do
      {:ok, response} -> {:ok, response}
    after
      5_000 -> :error
    end
  end

  @spec has_transaction(pid(), tx_id :: binary()) :: boolean()
  def has_transaction(pid, tx_id) do
    # hacky af but it does the job for now
    ws_pid = update_ws_with_caller(pid)

    message = Xogmios.Mempool.Messages.has_transaction(tx_id)
    :websocket_client.cast(ws_pid, {:text, message})

    receive do
      {:ok, response} -> {:ok, response}
    after
      5_000 -> :error
    end
  end

  # Updates Websocket process with self() as
  # caller and returns the Websocket process id
  defp update_ws_with_caller(pid) do
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

    ws_pid
  end

  defmacro __using__(_opts) do
    quote do
      @behaviour Xogmios.Mempool

      use Xogmios.Mempool.Connection

      require Logger

      def handle_connect(state), do: {:ok, state}
      def handle_disconnect(_reason, state), do: {:ok, state}
      def handle_acquired(_slot, state), do: {:ok, :next_transaction, state}
      defoverridable handle_connect: 1, handle_disconnect: 2, handle_acquired: 2

      def handle_message(
            %{
              "method" => "acquireMempool",
              "result" => %{"acquired" => "mempool", "slot" => slot} = _result
            },
            state
          ) do
        case state.handler.handle_acquired(%{"slot" => slot}, state) do
          {:ok, :next_transaction, new_state} ->
            message = Messages.next_transaction(state.include_details)
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
            %{
              "method" => "nextTransaction",
              "result" => %{"transaction" => nil} = _result
            },
            state
          ) do
        message = Messages.acquire_mempool()
        {:reply, {:text, message}, state}
      end

      def handle_message(
            %{
              "method" => "nextTransaction",
              "result" => %{"transaction" => transaction} = _result
            },
            state
          ) do
        case state.handler.handle_transaction(transaction, state) do
          {:ok, :next_transaction, new_state} ->
            message = Messages.next_transaction()
            {:reply, {:text, message}, new_state}

          {:ok, new_state} ->
            {:ok, new_state}

          {:close, new_state} ->
            {:close, "finished", new_state}

          response ->
            Logger.warning("Invalid response #{inspect(response)}")
        end
      end

      # Responds to synchronous call
      def handle_message(
            %{"method" => "sizeOfMempool", "result" => result},
            state
          ) do
        caller = Map.get(state, :caller)
        send(caller, {:ok, result})
        {:ok, state}
      end

      # Responds to synchronous call
      def handle_message(
            %{"method" => "hasTransaction", "result" => has_it},
            state
          ) do
        caller = Map.get(state, :caller)
        send(caller, {:ok, has_it})
        {:ok, state}
      end
    end
  end
end
