defmodule Xogmios do
  def chain_sync() do
    pid = GenServer.whereis(Xogmios.Websocket)
    Xogmios.Websocket.send_frame(pid, message())
  end

  def message do
    # Syncs with a recent Babbage block
    ~S"""
    {
      "jsonrpc": "2.0",
      "method": "findIntersection",
      "params": {
          "points": [
            {
              "slot": 112326383,
              "id": "c2a619903ab744b0820575b8ab09f8e4e7091f8d27c43d7e6455f289905a297a"
            }
        ]
      },
      "id": null
    }
    """
  end
end
