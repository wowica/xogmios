defmodule XogmiosTest do
  use ExUnit.Case

  @ws_url ChainSync.TestServer.get_url()

  setup_all do
    {:ok, _server} = ChainSync.TestServer.start()

    on_exit(fn ->
      ChainSync.TestServer.shutdown()
    end)

    :ok
  end

  defmodule DummyClient do
    use Xogmios.ChainSync

    def start_link(opts),
      do: start_connection(opts)

    @impl true
    def init(opts) do
      target = Keyword.get(opts, :target)
      {:ok, %{target: target}}
    end

    @impl true
    def handle_block(_block, state) do
      send(state.target, :handle_block)
      {:ok, :close, state}
    end
  end

  test "receives handle block" do
    pid = start_supervised!({DummyClient, url: @ws_url, target: self()})
    assert is_pid(pid)
    assert_receive :handle_block
  end

  test "terminates process when connection is closed" do
    pid = start_supervised!({DummyClient, url: @ws_url, target: self()})
    assert is_pid(pid)
    Process.sleep(1000)
    refute Process.alive?(pid)
    assert GenServer.whereis(DummyClient) == nil
  end

  test "restarts process when restart: :permanent" do
    pid =
      start_supervised!({DummyClient, url: @ws_url, target: self(), restart: :permanent})

    whereis_pid = GenServer.whereis(DummyClient)
    assert whereis_pid == pid
    assert is_pid(pid)
    Process.sleep(1000)
    assert GenServer.whereis(DummyClient) != nil
    assert GenServer.whereis(DummyClient) != whereis_pid
  end
end
