defmodule Xogmios.StateQuery do
  @moduledoc """
  This module interfaces with the State Query protocol.
  """

  alias Xogmios.StateQuery
  alias Xogmios.StateQuery.Messages
  alias Xogmios.StateQuery.Response
  alias Xogmios.StateQuery.Server

  @query_messages %{
    get_current_epoch: Messages.get_current_epoch(),
    get_era_start: Messages.get_era_start()
  }

  def query_messages, do: @query_messages

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
        with {:ok, message} <- Map.fetch(StateQuery.query_messages(), query),
             {:ok, %Response{} = response} <- GenServer.call(client, {:send_message, message}) do
          {:ok, response.result}
        else
          :error -> {:error, "Unsupported query"}
          {:error, _reason} -> {:error, "Error sending query"}
        end
      end

      def start_connection(opts),
        do: do_start_link(opts)

      def do_start_link(args),
        do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

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
