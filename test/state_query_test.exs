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
  end

  test "returns current epoch" do
    pid = start_supervised!({DummyClient, url: @ws_url})
    assert is_pid(pid)
    Process.sleep(1_000)
    expected_epoch = 333
    assert {:ok, ^expected_epoch} = DummyClient.get_current_epoch()
  end
end
