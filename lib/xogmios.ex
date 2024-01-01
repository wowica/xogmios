defmodule Xogmios do
  def chain_sync() do
    pid = GenServer.whereis(Xogmios.ClientExampleA)
    Xogmios.ClientExampleA.send_frame(pid, message())
  end

  def chain_sync_2() do
    pid = GenServer.whereis(Xogmios.ClientExampleB)
    Xogmios.ClientExampleB.send_frame(pid, message())
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
