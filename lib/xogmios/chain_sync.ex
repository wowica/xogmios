defmodule Xogmios.ChainSync do
  @moduledoc """
  This module defines the behaviour for ChainSync clients and
  implements the connection with the Websocket server
  """

  alias Xogmios.ChainSync.Messages

  @callback init(keyword()) :: {:ok, map()}
  @callback handle_block(map(), any()) ::
              {:ok, :next_block, map()} | {:ok, map()} | {:ok, :close, map()}

  defmacro __using__(_opts) do
    quote do
      @behaviour Xogmios.ChainSync

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
                message = Messages.next_block_start()
                send_frame(ws, message)

                {:ok, ws}
            after
              _timeout = 5_000 ->
                Kernel.send(ws, :close)
                {:error, :connection_timeout}
            end

          {:error, _} = error ->
            error
        end
      end

      def send_frame(connection, frame) do
        try do
          case WebSockex.send_frame(connection, {:text, frame}) do
            :ok -> :ok
            {:error, _reason} = error -> error
          end
        rescue
          _ -> {:error, :connection_down}
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
             %{
               "id" => "start",
               "method" => "nextBlock",
               "result" => %{"direction" => "backward", "tip" => tip} = _result
             } = _message,
             state
           ) do
        Logger.info("Finding intersection...")

        message = Messages.find_intersection(tip["slot"], tip["id"])

        {:reply, {:text, message}, state}
      end

      defp handle_message(
             %{"method" => "nextBlock", "result" => %{"direction" => "backward"}} = _message,
             state
           ) do
        message = Messages.next_block()

        {:reply, {:text, message}, state}
      end

      defp handle_message(
             %{"method" => "nextBlock", "result" => %{"direction" => "forward"} = result} =
               _message,
             state
           ) do
        block = result["block"]

        case apply(__MODULE__, :handle_block, [block, state]) do
          {:ok, :next_block, new_state} ->
            message = Messages.next_block()
            {:reply, {:text, message}, new_state}

          {:ok, new_state} ->
            {:ok, new_state}

          {:ok, :close, new_state} ->
            {:close, new_state}

          _ ->
            raise "Invalid return type"
        end
      end

      defp handle_message(%{"method" => "findIntersection"}, state) do
        Logger.info("Intersection found.")
        Logger.info("Waiting for next block...")

        message = Messages.next_block()

        {:reply, {:text, message}, state}
      end

      defp handle_message(message, state) do
        Logger.info("handle message: #{message}")
        {:ok, state}
      end

      def handle_connect(connection, %{notify_on_connect: pid} = state) do
        send(pid, {:connected, connection})
        {:ok, state}
      end

      def handle_disconnect(%{reason: {:local, reason}}, state) do
        Logger.info("#{__MODULE__} local close with reason: #{inspect(reason)}")
        {:ok, state}
      end
    end
  end
end
