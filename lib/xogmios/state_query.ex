defmodule Xogmios.StateQuery do
  @moduledoc """
  This module interfaces with the State Query protocol.
  """

  alias Xogmios.StateQuery.Messages
  alias Xogmios.StateQuery.Response
  alias Xogmios.StateQuery.Server

  @doc """
  Starts a new State Query process linked to the current process.

  This function should not be called directly, but rather via `Xogmios.start_state_link/2`
  """
  @spec start_link(module(), start_options :: Keyword.t()) :: GenServer.on_start()
  def start_link(client, opts) do
    GenServer.start_link(client, opts, name: client)
  end

  @doc """
  Sends a State Query call to the server and returns a response.

  This function is synchronous and takes two arguments:

  1. (Optional) A process reference. If none given, it defaults to the linked process `__MODULE__`.
  2. The name of the query to run.
  3. (Optional) Parameters to the query.

  Support for all [Ledger-state](https://ogmios.dev/mini-protocols/local-state-query/#ledger-state)
  and [Network](https://ogmios.dev/mini-protocols/local-state-query/#network) queries.

  For Ledger-state queries, only the name of the query is needed. For example:

  `StateQuery.send_query(pid, "epoch")` will send the query for ""queryLedgerState/epoch".

  For Network queries, the prefix "queryNetwork/" is needed. For example:

  `StateQueryClient.send_query("queryNetwork/blockHeight")` will send the query for "queryNetwork/blockHeight"
  """
  @spec send_query(pid() | atom(), String.t(), map()) :: {:ok, any()} | {:error, any()}

  def send_query(client, query, params \\ %{}) do
    with {:ok, message} <- build_query_message(query, params),
         {:ok, %Response{} = response} <- call_query(client, message) do
      {:ok, response.result}
    end
  end

  @valid_scopes ["queryNetwork", "queryLedgerState"]

  defp build_query_message(query_name, query_params) do
    query_message =
      case String.split(query_name, "/") do
        [scope, name] when scope in @valid_scopes ->
          Messages.build_message(scope, name, query_params)

        [name] ->
          Messages.build_message("queryLedgerState", name, query_params)
      end

    {:ok, query_message}
  end

  defp call_query(client, message) do
    case GenServer.call(client, {:send_message, message}) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  defmacro __using__(_opts) do
    quote do
      use GenServer

      ## Callbacks

      @impl true
      def init(args) do
        url = Keyword.fetch!(args, :url)
        initial_state = [notify_on_connect: self()]

        case :websocket_client.start_link(url, Server, initial_state) do
          {:ok, ws_pid} ->
            # Blocks until the connection with the Ogmios server
            # is established or until timeout is reached.
            receive do
              {:connected, _connection} ->
                {:ok, %{ws_pid: ws_pid, response: nil, caller: nil}}
            after
              _timeout = 5_000 ->
                send(ws_pid, :close)
                {:error, :connection_timeout}
            end

          {:error, _} = error ->
            error
        end
      end

      @impl true
      def handle_call({:send_message, message}, from, state) do
        {:store_caller, _from} = send(state.ws_pid, {:store_caller, from})
        :ok = :websocket_client.send(state.ws_pid, {:text, message})
        {:noreply, state}
      end
    end
  end
end
