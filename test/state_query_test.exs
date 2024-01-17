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

    def start_link(opts) do
      Xogmios.start_state_link(__MODULE__, opts)
    end

    def get_current_epoch() do
      case send_query(:get_current_epoch) do
        {:ok, result} -> result
        {:error, reason} -> "Something went wrong #{inspect(reason)}"
      end
    end

    def get_bananas() do
      case send_query(:get_bananas) do
        {:ok, result} -> result
        {:error, reason} -> "Something went wrong #{inspect(reason)}"
      end
    end
  end

  test "returns current epoch" do
    pid = start_supervised!({DummyClient, url: @ws_url})
    assert is_pid(pid)
    Process.sleep(1_000)
    assert DummyClient.get_current_epoch() == 333
    assert DummyClient.get_bananas() =~ "Something went wrong"
  end
end
