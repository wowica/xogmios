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
      {:close, state}
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

  defmodule DummyClientWithName do
    use Xogmios, :chain_sync

    def start_link(opts) do
      Xogmios.start_chain_sync_link(__MODULE__, opts)
    end

    @impl true
    def handle_block(_block, state) do
      send(state.test_handler, :handle_block)
      {:ok, state}
    end
  end

  test "allows multiple named processes" do
    opts1 = [url: @ws_url, test_handler: self(), name: :apple, id: :apple]
    pid1 = start_supervised!({DummyClientWithName, opts1})

    assert is_pid(pid1)
    assert Process.info(pid1)[:registered_name] == :apple

    opts2 = [url: @ws_url, test_handler: self(), name: :banana, id: :banana]
    pid2 = start_supervised!({DummyClientWithName, opts2})

    assert is_pid(pid2)
    assert pid1 != pid2
    assert Process.info(pid2)[:registered_name] == :banana

    # Duplicate process names raise error
    assert_raise RuntimeError, fn ->
      start_supervised!({DummyClientWithName, opts2})
    end

    # Process name must be atom
    opts22 = [url: @ws_url, test_handler: self(), name: "banana", id: :banana_string]
    {:error, {:invalid_process_name, _}} = start_supervised({DummyClientWithName, opts22})

    # Named via Registry
    opts3 = [
      url: @ws_url,
      test_handler: self(),
      name: {:via, Registry, {DummyRegistry, :apple}},
      id: :registry_apple
    ]

    _registry_pid = start_supervised!({Registry, keys: :unique, name: DummyRegistry})

    pid3 = start_supervised!({DummyClientWithName, opts3})

    assert is_pid(pid3)
    assert Process.info(pid3)[:registered_name] == nil
    assert [{^pid3, nil}] = Registry.lookup(DummyRegistry, :apple)

    # Global
    opts4 = [
      url: @ws_url,
      test_handler: self(),
      name: {:global, :global_banana},
      id: :global_banana
    ]

    pid4 = start_supervised!({DummyClientWithName, opts4})

    assert is_pid(pid4)
    # assert Process.info(pid4)[:registered_name] == :global_banana
  end
end
