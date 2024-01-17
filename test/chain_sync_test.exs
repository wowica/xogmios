defmodule Xogmios.ChainSyncTest do
  use ExUnit.Case

  @ws_url TestServer.get_url()

  setup_all do
    {:ok, _server} = TestServer.start(handler: ChainSync.TestHandler)

    on_exit(fn ->
      TestServer.shutdown()
    end)

    :ok
  end

  defmodule DummyClient do
    use Xogmios, :chain_sync

    def start_link(opts) do
      Xogmios.start_chain_sync_link(__MODULE__, opts)
    end

    @impl true
    def handle_block(_block, state) do
      send(state.test_handler, :handle_block)
      {:ok, :close, state}
    end
  end

  test "receives handle block" do
    pid = start_supervised!({DummyClient, url: @ws_url, test_handler: self()})
    assert is_pid(pid)
    assert_receive :handle_block
  end

  test "terminates process when connection is closed" do
    pid = start_supervised!({DummyClient, url: @ws_url, test_handler: self()})
    assert is_pid(pid)
    Process.sleep(500)
    refute Process.alive?(pid)
    assert GenServer.whereis(DummyClient) == nil
  end
end
