defmodule Xogmios.StateQueryTest do
  use ExUnit.Case

  @ws_url TestServer.get_url()

  setup_all do
    {:ok, _server} = TestServer.start(handler: StateQuery.TestHandler)

    on_exit(fn ->
      TestServer.shutdown()
    end)

    :ok
  end

  defmodule DummyClient do
    use Xogmios, :state_query
    alias Xogmios.StateQuery

    def start_link(opts) do
      Xogmios.start_state_link(__MODULE__, opts)
    end

    def get_current_epoch(pid \\ __MODULE__) do
      StateQuery.send_query(pid, "epoch")
    end

    def get_utxos_by_address(pid \\ __MODULE__) do
      params = %{
        addresses: ["addr_test1vp7yrmz5p6mdm3ph0a0jaxtk58hny3wseuw80fwql93huygczalde"]
      }

      StateQuery.send_query(pid, "utxo", params)
    end
  end

  test "returns current epoch" do
    # See test/support/state_query/test_handler.ex for fixture values
    pid = start_supervised!({DummyClient, url: @ws_url})
    assert is_pid(pid)
    Process.sleep(1_000)
    expected_epoch = 333
    assert {:ok, ^expected_epoch} = DummyClient.get_current_epoch()
    assert {:ok, [_utxo1, _utxo2]} = DummyClient.get_utxos_by_address()
  end
end
