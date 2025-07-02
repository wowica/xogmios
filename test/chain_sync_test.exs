defmodule Xogmios.ChainSyncTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

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

    global_pid4 = :global.whereis_name(:global_banana)

    assert is_pid(global_pid4)

    assert pid4 == global_pid4
  end

  defmodule DummyClientRollback do
    use Xogmios, :chain_sync

    def start_link(opts) do
      opts = Keyword.merge(opts, after_rollback: false)
      Xogmios.start_chain_sync_link(__MODULE__, opts)
    end

    @impl true
    def handle_block(_block, %{after_rollback: true} = state) do
      send(state.test_handler, :after_rollback)
      {:close, state}
    end

    @impl true
    def handle_block(_block, state) do
      send(state.test_handler, :handle_block)
      {:ok, :next_block, state}
    end

    @impl true
    def handle_rollback(point, state) do
      send(state.test_handler, {:rollback, point})
      new_state = Map.put(state, :after_rollback, true)
      {:ok, :next_block, new_state}
    end
  end

  test "handle_rollback" do
    pid = start_supervised!({DummyClientRollback, url: @ws_url, test_handler: self()})
    assert is_pid(pid)
    assert_receive :handle_block
    assert_receive {:rollback, point}
    assert point["id"]
    assert point["slot"]
    assert_receive :after_rollback
  end

  defmodule DummyClientWithTip do
    use Xogmios, :chain_sync

    def start_link(opts) do
      Xogmios.start_chain_sync_link(__MODULE__, opts)
    end

    @impl true
    def handle_block(block, state) do
      send(state.test_handler, {:handle_block, block})
      {:close, state}
    end
  end

  test "block includes current tip information" do
    pid = start_supervised!({DummyClientWithTip, url: @ws_url, test_handler: self()})
    assert is_pid(pid)

    assert_receive {:handle_block, block}
    assert is_map(block)
    assert Map.has_key?(block, "current_tip")
    assert is_map(block["current_tip"])
    assert Map.has_key?(block["current_tip"], "id")
    assert Map.has_key?(block["current_tip"], "slot")
  end

  defmodule DummyClientWithInfo do
    use Xogmios, :chain_sync

    def start_link(opts) do
      Xogmios.start_chain_sync_link(__MODULE__, opts)
    end

    @impl true
    def handle_block(_block, state) do
      send(state.test_handler, :handle_block)
      {:ok, state}
    end

    @impl true
    def handle_info(:request_next_block, state) do
      send(state.test_handler, :handle_info_request_next)
      {:ok, :next_block, state}
    end

    @impl true
    def handle_info(:just_ok, state) do
      send(state.test_handler, :handle_info_just_ok)
      {:ok, state}
    end

    @impl true
    def handle_info(:close_connection, state) do
      send(state.test_handler, :handle_info_close)
      {:close, state}
    end
  end

  describe "handle_info/2 callback" do
    test "returns :next_block to request next block" do
      pid = start_supervised!({DummyClientWithInfo, url: @ws_url, test_handler: self()})
      assert is_pid(pid)

      send(pid, :request_next_block)
      assert_receive :handle_info_request_next
      # Verify process is still alive after requesting next block
      assert Process.alive?(pid)
    end

    test "returns :ok to stop requesting blocks" do
      pid = start_supervised!({DummyClientWithInfo, url: @ws_url, test_handler: self()})
      assert is_pid(pid)

      send(pid, :just_ok)
      assert_receive :handle_info_just_ok
      # Verify process is still alive after just ok
      assert Process.alive?(pid)
    end

    test "returns :close to terminate connection" do
      pid = start_supervised!({DummyClientWithInfo, url: @ws_url, test_handler: self()})
      assert is_pid(pid)

      send(pid, :close_connection)
      assert_receive :handle_info_close
      # Give process time to terminate
      Process.sleep(100)
      # Verify process is terminated
      refute Process.alive?(pid)
    end
  end

  defmodule DummyClientWithCall do
    use Xogmios, :chain_sync

    def start_link(opts) do
      Xogmios.start_chain_sync_link(__MODULE__, opts)
    end

    @impl true
    def handle_block(_block, state) do
      send(state.test_handler, :handle_block)
      {:ok, state}
    end

    @impl true
    def handle_info({:test_message, caller, _ref}, state) do
      send(caller, {:ok, "test_response"})
      {:ok, state}
    end

    @impl true
    def handle_info({:error_message, caller, _ref}, state) do
      send(caller, {:error, "test_error"})
      {:ok, state}
    end

    @impl true
    def handle_info({:timeout_message, _caller, _ref}, state) do
      # Don't respond to simulate timeout
      {:ok, state}
    end
  end

  describe "call/2" do
    test "successfully calls process and receives response" do
      pid = start_supervised!({DummyClientWithCall, url: @ws_url, test_handler: self()})
      assert is_pid(pid)

      assert {:ok, "test_response"} = Xogmios.ChainSync.call(pid, :test_message)
    end

    test "handles error responses" do
      pid = start_supervised!({DummyClientWithCall, url: @ws_url, test_handler: self()})
      assert is_pid(pid)

      assert {:error, "test_error"} = Xogmios.ChainSync.call(pid, :error_message)
    end

    test "times out after 5 seconds" do
      pid = start_supervised!({DummyClientWithCall, url: @ws_url, test_handler: self()})
      assert is_pid(pid)

      assert {:error, :timeout} = Xogmios.ChainSync.call(pid, :timeout_message)
    end

    test "handles process not found error" do
      assert capture_log(fn ->
               assert {:error, :process_not_found} =
                        Xogmios.ChainSync.call(:nonexistent_process, :test_message)
             end) =~ "Error finding ChainSync process"
    end

    test "works with named processes" do
      opts = [url: @ws_url, test_handler: self(), name: :named_call_test]
      pid = start_supervised!({DummyClientWithCall, opts})
      assert is_pid(pid)

      assert {:ok, "test_response"} = Xogmios.ChainSync.call(:named_call_test, :test_message)
    end

    test "handles invalid process name error" do
      assert capture_log(fn ->
               assert {:error, :invalid_process_name} =
                        Xogmios.ChainSync.call("invalid process name", :test_message)
             end) =~ "Invalid process name"
    end

    test "works with global named processes" do
      opts = [
        url: @ws_url,
        test_handler: self(),
        name: {:global, :global_call_test}
      ]

      pid = start_supervised!({DummyClientWithCall, opts})
      assert is_pid(pid)

      assert {:ok, "test_response"} =
               Xogmios.ChainSync.call({:global, :global_call_test}, :test_message)
    end

    test "works with via registry processes" do
      opts = [
        url: @ws_url,
        test_handler: self(),
        name: {:via, Registry, {CallTestRegistry, :via_call_test}}
      ]

      _registry_pid = start_supervised!({Registry, keys: :unique, name: CallTestRegistry})

      pid = start_supervised!({DummyClientWithCall, opts})
      assert is_pid(pid)
      assert Process.info(pid)[:registered_name] == nil

      assert [{^pid, nil}] = Registry.lookup(CallTestRegistry, :via_call_test)

      assert {:ok, "test_response"} =
               Xogmios.ChainSync.call(
                 {:via, Registry, {CallTestRegistry, :via_call_test}},
                 :test_message
               )
    end
  end
end
