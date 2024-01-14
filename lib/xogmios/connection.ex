defmodule Xogmios.Connection do
  @moduledoc """
  This module implements the connection with the Ogmios Websocket server.
  """

  @start_messages %{
    chain_sync: Xogmios.ChainSync.Messages.next_block_start(),
    state_query: Xogmios.StateQuery.Messages.get_tip()
  }

  @spec start_messages() :: map()
  def start_messages, do: @start_messages

  defmacro __using__(ouroboros_protocol) do
    quote do
      use WebSockex

      @name __MODULE__

      require Logger

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          shutdown: 5_000,
          restart: Keyword.get(opts, :restart, :transient),
          type: :worker
        }
      end

      def init(_opts), do: {:ok, %{}}
      defoverridable init: 1

      def start_connection(opts),
        do: do_start_link(opts)

      def do_start_link(opts) do
        url = Keyword.get(opts, :url)
        name = Keyword.get(opts, :name, @name)
        protocol = unquote(ouroboros_protocol)

        {:ok, init_state} = apply(__MODULE__, :init, [opts])
        initial_state = Map.merge(init_state, %{notify_on_connect: self()})

        case WebSockex.start_link(url, __MODULE__, initial_state, name: name) do
          {:ok, ws} ->
            receive do
              {:connected, _connection} ->
                start_message = Map.get(Xogmios.Connection.start_messages(), protocol)
                send_frame(ws, start_message)

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
