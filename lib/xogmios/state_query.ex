defmodule Xogmios.StateQuery do
  @moduledoc """
  This module defines the behaviour for StateQuery clients and
  implements the connection with the Websocket server
  """

  alias Xogmios.StateQuery.Messages

  @allowed_queries [:get_current_epoch, :get_era_start]

  @query_messages %{
    get_current_epoch: Messages.get_current_epoch(),
    get_era_start: Messages.get_era_start()
  }

  @method_queries %{
    "queryLedgerState/epoch" => :get_current_epoch,
    "queryLedgerState/eraStart" => :get_era_start
  }

  @callback init(keyword()) :: {:ok, map()}
  @callback handle_query_response(map(), any()) :: {:ok, map()} | {:ok, :close, map()}

  @spec allowed_queries() :: list()
  def allowed_queries, do: @allowed_queries

  @spec query_messages() :: map()
  def query_messages, do: @query_messages

  @spec method_queries() :: map()
  def method_queries, do: @method_queries

  defmacro __using__(_opts) do
    quote do
      @behaviour Xogmios.StateQuery

      use WebSockex

      require Logger

      @name __MODULE__

      def init(_opts), do: {:ok, %{}}
      defoverridable init: 1

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          shutdown: 5_000,
          restart: Keyword.get(opts, :restart, :transient),
          type: :worker
        }
      end

      def start_connection(opts),
        do: do_start_link(opts)

      def do_start_link(opts) do
        url = Keyword.get(opts, :url)
        name = Keyword.get(opts, :name, @name)

        {:ok, init_state} = apply(__MODULE__, :init, [opts])
        initial_state = Map.merge(init_state, %{notify_on_connect: self()})

        case WebSockex.start_link(url, __MODULE__, initial_state, name: name) do
          {:ok, ws} ->
            receive do
              {:connected, _connection} ->
                message = Messages.get_tip()
                send_frame(ws, message)

                {:ok, ws}
            after
              _timeout = 5_000 ->
                Kernel.send(ws, :close)
                {:error, :connection_timeout}
            end

          {:error, reason} = error ->
            Logger.warning("Error starting WebSockex process #{inspect(reason)}")
            error
        end
      end

      def send_query(query) do
        message = Map.get(Xogmios.StateQuery.query_messages(), query)

        if message do
          send_frame(__MODULE__, message)
        else
          Logger.warning("Invalid query #{query}")
        end
      end

      def send_frame(connection, frame) do
        try do
          case WebSockex.send_frame(connection, {:text, frame}) do
            :ok ->
              :ok

            {:error, reason} = error ->
              Logger.warning("Error sending frame #{inspect(reason)}")
              error
          end
        rescue
          reason ->
            Logger.warning("Error sending frame: #{inspect(reason)}")
            {:error, :connection_down}
        end
      end

      def handle_frame({_type, msg}, state) do
        case Jason.decode(msg) do
          {:ok, message} ->
            handle_message(message, state)

          {:error, error} ->
            Logger.warning("Error decoding response #{inspect(error)}")
            {:close, state}
        end
      end

      defp handle_message(
             %{"method" => "queryNetwork/tip"} = message,
             state
           ) do
        Logger.info("queryNetwork/top")
        point = message["result"]
        message = Messages.acquire_ledger_state(point)
        {:reply, {:text, message}, state}
      end

      defp handle_message(
             %{"method" => "acquireLedgerState"} = message,
             state
           ) do
        Logger.info("Ready for queries")
        {:ok, state}
      end

      defp handle_message(
             %{"method" => method, "result" => result} = _message,
             state
           ) do
        response =
          %{
            result: result,
            query: Map.get(Xogmios.StateQuery.method_queries(), method)
          }

        case apply(__MODULE__, :handle_query_response, [response, state]) do
          {:ok, new_state} ->
            {:ok, new_state}

          {:ok, :close, new_state} ->
            Logger.debug("Closing with new state")
            {:close, new_state}

          _ ->
            Logger.warning("Invalid client callback response")
        end
      end

      defp handle_message(message, state) do
        Logger.info("uncaught message: #{inspect(message)}")
        {:ok, state}
      end

      def handle_connect(connection, %{notify_on_connect: pid} = state) do
        send(pid, {:connected, connection})
        {:ok, state}
      end

      def handle_disconnect(%{reason: {:local, reason}}, state) do
        {:ok, state}
      end
    end
  end
end
