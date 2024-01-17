defmodule TestRouter do
  @moduledoc false

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  match _ do
    send_resp(conn, 200, "waiting for ws")
  end

  def options(opts) do
    dispatch = [
      {:_,
       [
         {"/ws/[...]", opts[:handler], []}
       ]}
    ]

    port = opts[:port] || 8088

    [port: port, dispatch: dispatch]
  end
end
