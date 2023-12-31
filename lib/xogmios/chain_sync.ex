defmodule Xogmios.ChainSync do
  @moduledoc """
  This module defines the behaviour for ChainSync clients and
  implements the connection with the Websocket server
  """

  @callback init() :: {:ok, map()}
  @callback handle_block(map(), any()) :: {:ok, :next_block, map()} | {:ok, map()}

  defmacro __using__(_opts) do
    quote do
      use WebSockex
      @behaviour Xogmios.ChainSync

      @name __MODULE__

      def start_connection(opts), do: do_start_link(opts)

      def do_start_link(opts) do
        url = Keyword.get(opts, :url)
        name = Keyword.get(opts, :name, @name)

        {:ok, init_state} = apply(__MODULE__, :init, [])
        initial_state = Map.merge(init_state, %{notify_on_connect: self()})

        case WebSockex.start_link(url, __MODULE__, initial_state, name: name) do
          {:ok, ws} ->
            receive do
              {:connected, connection} ->
                start = ~S"""
                {
                  "jsonrpc": "2.0",
                  "method": "nextBlock",
                  "id": "start"
                }
                """

                send_frame(ws, start)

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

      def init() do
        {:ok, %{}}
      end

      defoverridable init: 0

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
            IO.puts("Error decoding response #{inspect(error)}")
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
        IO.puts("Finding intersection...\n")

        reply = ~s"""
        {
          "jsonrpc": "2.0",
          "method": "findIntersection",
          "params": {
              "points": [
                {
                  "slot": #{tip["slot"]},
                  "id": "#{tip["id"]}"
                }
            ]
          }
        }
        """

        {:reply, {:text, reply}, state}
      end

      defp handle_message(
             %{"method" => "nextBlock", "result" => %{"direction" => "backward"}} = _message,
             state
           ) do
        reply = ~S"""
        {
          "jsonrpc": "2.0",
          "method": "nextBlock"
        }
        """

        {:reply, {:text, reply}, state}
      end

      defp handle_message(
             %{"method" => "nextBlock", "result" => %{"direction" => "forward"} = result} =
               _message,
             state
           ) do
        block = result["block"]

        case apply(__MODULE__, :handle_block, [block, state]) do
          {:ok, :next_block, new_state} ->
            reply = ~S"""
            {
              "jsonrpc": "2.0",
              "method": "nextBlock"
            }
            """

            {:reply, {:text, reply}, new_state}

          {:ok, new_state} ->
            {:ok, new_state}

          _ ->
            raise "Invalid return type"
        end
      end

      defp handle_message(%{"method" => "findIntersection"}, state) do
        IO.puts("Intersection found.\nWaiting for next block...\n")

        reply = ~S"""
        {
          "jsonrpc": "2.0",
          "method": "nextBlock"
        }
        """

        {:reply, {:text, reply}, state}
      end

      defp handle_message(message, state) do
        IO.puts("handle_message #{inspect(message)}")
        {:ok, state}
      end

      def handle_connect(connection, %{notify_on_connect: pid} = state) do
        send(pid, {:connected, connection})
        {:ok, state}
      end

      def handle_disconnect(%{reason: {:local, reason}}, state) do
        IO.puts("Local close with reason: #{inspect(reason)}")
        {:ok, state}
      end
    end
  end
end
