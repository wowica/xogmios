defmodule Xogmios do
  def chain_sync() do
    pid = GenServer.whereis(Xogmios.Connection)
    Xogmios.Connection.send_frame(pid, message())
  end

  def chain_sync_2() do
    pid = GenServer.whereis(Xogmios.Client)
    Xogmios.Client.send_frame(pid, message())
  end

  defp message do
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
