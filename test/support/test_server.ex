defmodule TestServer do
  @moduledoc false

  @default_port 8989

  def get_url(port \\ @default_port) do
    "ws://localhost:#{port}/ws"
  end

  def start(port \\ @default_port, handler: handler) do
    cowboy_server =
      Plug.Cowboy.http(
        WebSocket.Router,
        [scheme: :http],
        TestRouter.options(port: port, handler: handler)
      )

    cowboy_server =
      case cowboy_server do
        {:error, {:already_started, server}} -> server
        pid -> pid
      end

    {:ok, cowboy_server}
  end

  def shutdown() do
    Plug.Cowboy.shutdown(WebSocket.Router.HTTP)
  end
end
