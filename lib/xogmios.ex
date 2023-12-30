defmodule Xogmios do
  def chain_sync() do
    pid = GenServer.whereis(Xogmios.Websocket)
    Xogmios.Websocket.send_frame(pid, message())
  end

  def message do
    # Syncs with tip
    ~S"""
      {
        "jsonrpc": "2.0",
        "method": "nextBlock",
        "id": "start"
    }
    """
  end
end
