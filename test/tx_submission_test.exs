defmodule Xogmios.TxSubmissionTest do
  use ExUnit.Case

  @ws_url TestServer.get_url()

  setup_all do
    {:ok, _server} = TestServer.start(handler: TxSubmission.TestHandler)

    on_exit(fn ->
      TestServer.shutdown()
    end)

    :ok
  end

  defmodule DummyClient do
    use Xogmios, :tx_submission
    alias Xogmios.TxSubmission

    def start_link(opts) do
      Xogmios.start_tx_submission_link(__MODULE__, opts)
    end

    def submit_tx(pid \\ __MODULE__, cbor) do
      TxSubmission.submit_tx(pid, cbor)
    end

    def evaluate_tx(pid \\ __MODULE__, cbor) do
      TxSubmission.evaluate_tx(pid, cbor)
    end
  end

  test "transaction submission" do
    pid = start_supervised!({DummyClient, url: @ws_url})
    assert is_pid(pid)
    Process.sleep(1_000)

    assert {:ok, %{"transaction" => %{"id" => _id}}} =
             DummyClient.submit_tx(_cbor = "valid-cbor-value")

    assert {:error, info} =
             DummyClient.submit_tx(_cbor = "invalid-cbor-value")

    assert info["code"] == -32_602
    assert data = info["data"]
    eras = Map.keys(data)

    for era <- eras do
      assert era in ["allegra", "alonzo", "babbage", "conway", "mary", "shelley"]
      assert data[era] =~ "invalid or incomplete value of"
    end

    assert info["message"] =~ "Invalid transaction"
  end

  test "transaction evaluation" do
    pid = start_supervised!({DummyClient, url: @ws_url})
    assert is_pid(pid)
    Process.sleep(1_000)

    assert {:ok, [%{"budget" => _budget, "validator" => _validator}]} =
             DummyClient.evaluate_tx(_cbor = "valid-cbor-value-evaluate")

    assert {:error, info} =
             DummyClient.evaluate_tx(_cbor = "invalid-cbor-value-evaluate")

    assert info["code"] == -32_602
    assert data = info["data"]
    eras = Map.keys(data)

    for era <- eras do
      assert era in ["allegra", "alonzo", "babbage", "conway", "mary", "shelley"]
      assert data[era] =~ "invalid or incomplete value of"
    end

    assert info["message"] =~ "Invalid transaction"
  end
end
