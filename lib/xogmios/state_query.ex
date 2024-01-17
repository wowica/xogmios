defmodule Xogmios.StateQuery do
  @moduledoc """
  This module interfaces with the State Query protocol.
  """

  alias Xogmios.StateQuery
  alias Xogmios.StateQuery.Messages
  alias Xogmios.StateQuery.Response
  alias Xogmios.StateQuery.Server

  def start_link(client, opts) do
    GenServer.start_link(client, opts, name: client)
  end

  @query_messages %{
    get_current_epoch: Messages.get_current_epoch(),
    get_era_start: Messages.get_era_start()
  }

  @allowed_queries Map.keys(@query_messages)

  def fetch_query_message(query) when query in @allowed_queries,
    do: Map.fetch(@query_messages, query)

  def fetch_query_message(query),
    do: {:error, "Unsupported query #{inspect(query)}"}

  def call_query(client, message) do
    case GenServer.call(client, {:send_message, message}) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, reason}
    end
  end

  defmacro __using__(_opts) do
    quote do
      use GenServer

      ## Client API

      @doc """
      Sends a State Query call to the server and returns a response.
      This function is synchornous.
      """
      @spec send_query(term(), term()) :: {:ok, any()} | {:error, any()}
      def send_query(client \\ __MODULE__, query) do
        with {:ok, message} <- StateQuery.fetch_query_message(query),
             {:ok, %Response{} = response} <- StateQuery.call_query(client, message) do
          {:ok, response.result}
        end
      end

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
        send(state.ws_pid, {:store_caller, from})
        :ok = :websocket_client.send(state.ws_pid, {:text, message})
        {:noreply, state}
      end
    end
  end
end
