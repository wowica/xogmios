defmodule Xogmios.Websocket do
  use WebSockex

  @name __MODULE__

  def start_link(opts) do
    url = Keyword.get(opts, :url)
    name = Keyword.get(opts, :name, @name)

    case WebSockex.start_link(url, __MODULE__, %{notify_on_connect: self()},
           name: name
           # debug: [:trace]
         ) do
      {:ok, ws} ->
        receive do
          {:connected, _connection} ->
            IO.puts("connected!")
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
        IO.puts("Error decoding response #{inspect(error)}")
        {:close, state}
    end
  end

  defp handle_message(
         %{"method" => "nextBlock", "result" => %{"direction" => "backward"} = _point} = _message,
         state
       ) do
    # TODO: roll back Agent db to this point

    # First 5 blocks
    # message = ~s"""
    #   {
    #     "jsonrpc": "2.0",
    #     "method": "nextBlock",
    #     "id": "5"
    # }
    # """

    message = ~s"""
      {
        "jsonrpc": "2.0",
        "method": "nextBlock"
    }
    """

    {:reply, {:text, message}, state}
  end

  defp handle_message(
         %{"method" => "nextBlock", "result" => %{"direction" => "forward"} = result} = _message,
         state
       ) do
    IO.puts(result["block"]["height"])
    IO.puts(result["block"]["id"])

    # First 5 blocks
    # next_id = String.to_integer(message["id"]) - 1

    # if next_id > 0 do
    #   message = ~s"""
    #     {
    #       "jsonrpc": "2.0",
    #       "method": "nextBlock",
    #       "id": "#{next_id}"
    #   }
    #   """

    #   {:reply, {:text, message}, state}
    # else
    #   {:ok, state}
    # end

    message = ~s"""
      {
        "jsonrpc": "2.0",
        "method": "nextBlock"
    }
    """

    {:reply, {:text, message}, state}
  end

  defp handle_message(%{"method" => "findIntersection"}, state) do
    message = ~s"""
      {
        "jsonrpc": "2.0",
        "method": "nextBlock"
    }
    """

    {:reply, {:text, message}, state}
  end

  defp handle_message(message, state) do
    IO.inspect("handle_message #{inspect(message)}")
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
