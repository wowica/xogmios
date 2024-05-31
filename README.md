# Xogmios

![CI Status](https://github.com/wowica/xogmios/actions/workflows/ci.yml/badge.svg)
[![Version](https://img.shields.io/hexpm/v/xogmios.svg)](https://hex.pm/packages/xogmios)

[Docs](https://hexdocs.pm/xogmios/)

An Elixir client for [Ogmios](https://github.com/CardanoSolutions/ogmios).

> Ogmios is a lightweight bridge interface for a Cardano node. It offers a WebSockets API that enables local clients to speak Ouroboros' mini-protocols via JSON/RPC. - https://ogmios.dev/

Mini-Protocols supported by this library:

- [x] Chain Synchronization
- [x] State Query
- [x] Tx Submission
- [ ] Mempool Monitoring

See [Examples](#examples) section below for information on how to use this library.

## Installing

Add the dependency to `mix.exs`:

```elixir
defp deps do
  [
    {:xogmios, "~> 0.3.0"}
  ]
end
```

Add your client modules to your application's supervision tree as such:

```elixir
# file: application.ex
def start(_type, _args) do
  ogmios_url = System.fetch_env!("OGMIOS_URL")

  children = [
    {ChainSyncClient, url: ogmios_url},
    {StateQueryClient, url: ogmios_url},
    {TxSubmissionClient, url: ogmios_url}
  ]
  #...
end
```

The value for the `url` option should be set to the address of your Ogmios instance.

See section below for examples of client modules.

## Examples

### Chain Sync

The following is an example of a module that implement the **Chain Sync** behaviour. In this example, the client syncs with the tip of the chain, reads the next 3 blocks and then closes the connection with the server.

```elixir
defmodule ChainSyncClient do
  use Xogmios, :chain_sync

  def start_link(opts) do
    initial_state = [counter: 3]
    opts = Keyword.merge(opts, initial_state)
    Xogmios.start_chain_sync_link(__MODULE__, opts)
  end

  @impl true
  def handle_block(block, %{counter: counter} = state) when counter > 1 do
    IO.puts("handle_block #{block["height"]}")
    {:ok, :next_block, %{state | counter: counter - 1}}
  end

  @impl true
  def handle_block(block, state) do
    IO.puts("final handle_block #{block["height"]}")
    {:close, state}
  end

  @impl true
  def handle_rollback(point, state) do
    IO.puts("handle_rollback")

    # Use this information to update your custom state accordingly
    IO.puts("Block id: #{point["id"]}")
    IO.puts("Slot: #{point["slot"]}")

    {:ok, :next_block, state}
  end
end
```

### State Query

The following illustrates working with the **State Query** protocol. It runs queries against the tip of the chain.

```elixir
defmodule StateQueryClient do
  use Xogmios, :state_query
  alias Xogmios.StateQuery

  def start_link(opts) do
    Xogmios.start_state_link(__MODULE__, opts)
  end

  def get_current_epoch(pid \\ __MODULE__) do
    # Defaults to Ledger-state queries.
    # The following call is the same as calling
    # `StateQuery.send_query(pid, "queryLedgerState/epoch")`
    StateQuery.send_query(pid, "epoch")
  end

  def get_network_height(pid \\ __MODULE__) do
    # For network queries, scope must be explicitly used.
    StateQuery.send_query(pid, "queryNetwork/blockHeight")`
  end

  def send_query_no_params(pid \\ __MODULE__, query_name) do
    StateQuery.send_query(pid, query_name)
  end

  def send_query(pid \\ __MODULE__, query_name, query_params) do
    # Optional query params are sent as the third argument
    # to StateQuery.send_query/3
    StateQuery.send_query(pid, query_name, query_params)
  end
end
```

### Tx Submission

The following illustrates working with the **Transaction Submission** protocol. It submits a signed transaction, represented as a CBOR, to the Ogmios server.

```elixir
defmodule TxSubmissionClient do
  use Xogmios, :tx_submission
  alias Xogmios.TxSubmission

  def start_link(opts) do
    Xogmios.start_tx_submission_link(__MODULE__, opts)
  end

  def submit_tx(pid \\ __MODULE__, cbor) do
    # The CBOR must be a valid transaction,
    # properly built and signed
    TxSubmission.submit_tx(pid, cbor)
  end
end
```

For examples of applications using this library, see [Blocks](https://github.com/wowica/blocks) and [xogmios_watcher](https://github.com/wowica/xogmios_watcher).

## Test

Run `mix test`. Tests do NOT rely on a running Ogmios instance.
