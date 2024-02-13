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

  @query_messages %{
    get_current_epoch: Messages.get_current_epoch(),
    get_era_start: Messages.get_era_start()
  }

  @allowed_queries Map.keys(@query_messages)

  @doc """
  Sends a State Query call to the server and returns a response.

  This function is synchronous and takes two arguments:

  1. (Optional) A process reference. If none given, it defaults to the linked process `__MODULE__`.
  2. The query to run. Support for [all available queries](https://ogmios.dev/mini-protocols/local-state-query/#network)
  is actively being worked on. For the time being, it only accepts the following values: #{@allowed_queries |> Enum.map_join(",", fn query -> "`#{inspect(query)}`" end)}

  """
  @spec send_query(pid() | atom(), atom()) :: {:ok, any()} | {:error, any()}
  def send_query(client \\ __MODULE__, query) do
    with {:ok, message} <- fetch_query_message(query),
         {:ok, %Response{} = response} <- call_query(client, message) do
      {:ok, response.result}
    end
  end

  defp fetch_query_message(query) when query in @allowed_queries,
    do: Map.fetch(@query_messages, query)

  defp fetch_query_message(query),
    do: {:error, "Unsupported query #{inspect(query)}"}

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
