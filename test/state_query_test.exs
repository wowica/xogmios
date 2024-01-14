defmodule StateQueryTest do
  use ExUnit.Case

  @ws_url StateQuery.TestServer.get_url()

  setup_all do
    {:ok, _server} = StateQuery.TestServer.start()

    on_exit(fn ->
      StateQuery.TestServer.shutdown()
    end)

    :ok
  end

  defmodule DummyClient do
    use Xogmios.StateQuery

    def start_link(opts),
      do: start_connection(opts)

    def get_current_epoch(),
      do: send_query(:get_current_epoch)

    @impl true
    def init(opts) do
      target = Keyword.get(opts, :target)
      should_close = Keyword.get(opts, :should_close, false)
      {:ok, %{target: target, should_close: should_close}}
    end

    @impl true
    def handle_query_response(_response, state) do
      send(state.target, :handle_query_response)

      if state.should_close do
        {:ok, :close, state}
      else
        {:ok, state}
      end
    end
  end

  test "get_current_epoch/0 and keeps connection open" do
    pid = start_supervised!({DummyClient, url: @ws_url, target: self()})
    assert is_pid(pid)
    DummyClient.get_current_epoch()
    assert_receive :handle_query_response
    Process.sleep(1000)
    assert Process.alive?(pid)
    assert GenServer.whereis(DummyClient) != nil
  end

  test "get_current_epoch/0 and closes connection" do
    pid = start_supervised!({DummyClient, url: @ws_url, target: self(), should_close: true})
    assert is_pid(pid)
    DummyClient.get_current_epoch()
    assert_receive :handle_query_response
    Process.sleep(1000)
    refute Process.alive?(pid)
    assert GenServer.whereis(DummyClient) == nil
  end
end
