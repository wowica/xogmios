defmodule Xogmios.MempoolTest do
  use ExUnit.Case

  @ws_url TestServer.get_url()

  setup_all do
    {:ok, _server} = TestServer.start(handler: Mempool.TestHandler)

    on_exit(fn ->
      TestServer.shutdown()
    end)

    :ok
  end

  defmodule DummyClient do
    use Xogmios, :mempool

    def start_link(opts) do
      Xogmios.start_mempool_link(__MODULE__, opts)
    end

    @impl true
    def handle_acquired(_snapshot, state) do
      send(state.test_handler, :handle_acquired)
      {:ok, :next_transaction, state}
    end

    @impl true
    def handle_transaction(_block, state) do
      send(state.test_handler, :handle_transaction)
      {:close, state}
    end
  end

  test "receives callbacks and closes connection" do
    pid = start_supervised!({DummyClient, url: @ws_url, test_handler: self()})
    assert is_pid(pid)

    assert_receive :handle_acquired
    assert_receive :handle_transaction

    Process.sleep(500)
    refute Process.alive?(pid)
    assert GenServer.whereis(DummyClient) == nil
  end
end
