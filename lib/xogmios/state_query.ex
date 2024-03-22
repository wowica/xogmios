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
  2. The query to run. Support for [all available queries](https://ogmios.dev/mini-protocols/local-state-query/#network)

  """
  @spec send_query(pid() | atom(), String.t()) :: {:ok, any()} | {:error, any()}
  def send_query(client \\ __MODULE__, query_name) do
    with {:ok, message} <- build_query_message(query_name),
         {:ok, %Response{} = response} <- call_query(client, message) do
      {:ok, response.result}
    end
  end

  @valid_scopes ["queryNetwork", "queryLedgerState"]

  defp build_query_message(query_name) do
    query_message =
      case String.split(query_name, "/") do
        [scope, name] when scope in @valid_scopes ->
          Messages.build_message(scope, name)

        [name] ->
          Messages.build_message(name)
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

        case :websocket_client.start_link(url, Server, []) do
          {:ok, ws_pid} ->
            {:ok, %{ws_pid: ws_pid, response: nil, caller: nil}}

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
