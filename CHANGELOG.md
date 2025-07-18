# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v0.7.1](https://github.com/wowica/xogmios/releases/tag/v0.7.1) (2025-07-16)

### Fixed

- Fixed a spec warning on `Xogmios.ChainSync.call/2` function.

## [v0.7.0](https://github.com/wowica/xogmios/releases/tag/v0.7.0) (2025-07-11)

### Fixed

- Fixed a type mismatch on `Xogmios.HealthCheck.run/1` that was causing a warning on calls to `use Xogmios, :chain_sync`.

### Added

- New `Xogmios.ChainSync.call/2` function to send synchronous messages to the ChainSync process and an accompanying `handle_info/2` callback. Example usage of both:

  ```elixir
  defmodule ChainSyncBlockCounter do
    use Xogmios, :chain_sync

    def start_link(opts) do
      initial_state = [block_count: 0, sync_from: :origin]
      opts = Keyword.merge(opts, initial_state)
      Xogmios.start_chain_sync_link(__MODULE__, opts)
    end

    # Returns the current number of blocks synced
    def get_block_count(pid \\ __MODULE__) do
      # Data is pulled, as it's returned to the 
      # caller of `ChainSyncBlockCounter.get_block_count/1`
      Xogmios.ChainSync.call(pid, :get_block_count)
    end

    @impl true
    def handle_info({:get_block_count, caller, _ref}, state) do
      send(caller, {:ok, state.block_count})
      {:ok, state}
    end

    @impl true
    def handle_block(_block, %{block_count: block_count} = state) do
      # Data is pushed, like `Indexer.push(block)`
      {:ok, :next_block, %{state | block_count: block_count + 1}}
    end
  end
  ```

- Current tip information is now included in the block data passed to `handle_block/2` under the `current_tip` key. This allows clients to calculate the time needed for chainsync to sync from the current position. Adding this to the existing block for now to quickly enable other features, but we should consider implementing a new callback (like `handle_forward/2`) to better handle a new top level entity with both "block" and "tip" as properties. Example of a match for when the client is synced with the current tip (note the repeating `slot` variable name):

  ```elixir
  @impl true
  def handle_block(
    %{
      "slot" => slot,
      "current_tip" => %{"slot" => slot},
    } = block,
    state
  ) do
    # ... process the block
    {:ok, :next_block, state}
  end
  ```

- New syntax for setting an intersection point on `ChainSync`:

  ```elixir
  sync_from: {slot, block_hash}
  ```

### Deprecated

- The following syntax for setting an intersection point on `ChainSync` is now deprecated:

  ```elixir
  sync_from: %{
    point: %{slot: slot, id: block_hash}
  }
  ```
- Optional `handle_info/2` callback for ChainSync clients. This allows handling of arbitrary
messages sent to the ChainSync process, with support for requesting next blocks, stopping block
requests, or closing the connection.

### Removed

- Removed `read_next_block/1` function from ChainSync. This function was a failed attempt at sending synchronous messages to ChainSync.

## [v0.6.1](https://github.com/wowica/xogmios/releases/tag/v0.6.1) (2024-12-22)

### Fixed

- Fixed a bug where new Ogmios connections were being created for each reconnection attempt. The fix
ensures the current connection is closed prior to attempting to reconnect. This is in the context of
when the underlying Cardano node is still syncing.

## [v0.6.0](https://github.com/wowica/xogmios/releases/tag/v0.6.0) (2024-10-03)

### Fixed

- Connecting to Ogmios when the underlying Cardano node is not yet ready or still syncinging with
the network. Xogmios now reports back sync status and attempts a reconnection after 5 seconds.

### Added

- Support for `:conway` to the `sync_from` option on ChainSync (mainnet only). This allows ChainSync
clients to sync with the chain starting on the first block of the Conway era.

### Changed

- The original Erlang websocket client library was replaced by [banana_websocket_client](https://hex.pm/packages/banana_websocket_client).
This is a fork of the original library including a few additions needed by Xogmios and which needed
to be republished as a library in order to meet Hex package manager's requirements that all
package dependencies must be a package themselves.

## [v0.5.1](https://github.com/wowica/xogmios/releases/tag/v0.5.1) (2024-09-04)

### Fixed

- Errors on tx submission and tx evaluation now return complete information from Ogmios.

## [v0.5.0](https://github.com/wowica/xogmios/releases/tag/v0.5.0) (2024-08-16)

### Added

- Initial support for Mempool monitoring mini-protocol. Allows reading transactions from the mempool.
- mix task for generating boilerplate code for client modules. See `mix help xogmios.gen.client`

## [v0.4.1](https://github.com/wowica/xogmios/releases/tag/v0.4.1) (2024-06-05)

### Fixed

- ChainSync reconnection issue (#33)

## [v0.4.0](https://github.com/wowica/xogmios/releases/tag/v0.4.0) (2024-05-31)

### Added

- ChainSync rollback event.

- Experimental ChainSync manual syncing mechanism API. This adds an optional back-pressure when building chain indexers that rely on Xogmios. Tested with GenStage on [the following experimental branch](https://github.com/wowica/xogmios_watcher/tree/chain-indexer).

### Fixed

- Process naming for ChainSync clients. It is now possible to given different process names and ids as options to ChainSync clients, allowing multiple clients to run.

## [v0.3.0](https://github.com/wowica/xogmios/releases/tag/v0.3.0) (2024-03-29)

### Changed

- StateQuery.send_query interface. Now accepts queries as strings from user input.

### Fixed

- Avoid race condition on state queries by blocking until connection with the Ogmios server is established.

## [v0.2.0](https://github.com/wowica/xogmios/releases/tag/v0.2.0) (2024-02-24)

## Added

- Support for Tx Submission procotol
  - Submit signed transactions
  - Evaluate execution units of given transaction

## [v0.1.0](https://github.com/wowica/xogmios/releases/tag/v0.1.0) (2024-02-13)

### Added

- Support for Chain Sync protocol
- Partial support for Ledger State Queries:
  - epoch
  - eraStart
