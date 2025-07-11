defmodule Xogmios do
  @moduledoc """
  This is the top level module for Xogmios. It implements functions to be used by client
  modules that wish to connect with Ogmios.

  When you `use` this module, it expects one of the supported mini-protocols as argument. For example:

      defmodule ChainSyncClient do
        use Xogmios, :chain_sync
        # ...
      end

      defmodule StateQueryClient do
        use Xogmios, :state_query
        # ...
      end

      defmodule TxSubmissionClient do
        use Xogmios, :tx_submission
        # ...
      end

      defmodule MempoolTxsClient do
        use Xogmios, :mempool_txs
        # ...
      end
  """

  alias Xogmios.ChainSync
  alias Xogmios.StateQuery
  alias Xogmios.TxSubmission
  alias Xogmios.MempoolTxs

  @doc """
  Starts a new State Query process linked to the current process.

  `opts` are be passed to the underlying GenServer.
  """
  def start_state_link(client, opts) do
    StateQuery.start_link(client, opts)
  end

  @doc """
  Starts a new Chain Sync process linked to the current process.

  The `sync_from` option can be passed as part of `opts` to define at which point
  the chain should be synced from.

  This option accepts either:

  a) An atom from the following list of existing eras: `:origin`, `:byron`,
  `:shelley`, `:allegra`, `:mary`, `:alonzo`, `:babbage`, `:conway`.

  For example:

  ```elixir
  def start_link(opts) do
    initial_state = [sync_from: :babbage]
    opts = Keyword.merge(opts, initial_state)
    Xogmios.start_chain_sync_link(__MODULE__, opts)
  end
  ```

  This will sync with the chain starting from the first block of the Babbage era. Passing
  an atom to `sync_from` only works when connecting with **mainnet**. For testnet, `sync_from`
  must receive a specific point in the chain as described below.

  b) A point in the chain using a tuple of `{slot, block_hash}`. For example:

  ```elixir
  def start_link(opts) do
    initial_state = [
      sync_from: {114_127_654, "b0ff1e2bfc326a7f7378694b1f2693233058032bfb2798be2992a0db8b143099"}
    ]
    opts = Keyword.merge(opts, initial_state)
    Xogmios.start_chain_sync_link(__MODULE__, opts)
  end
  ```

  This will sync with the chain starting from the first block **after** the specified point.

  All other options passed as part of `opts` will be available in the `state` argument for `c:Xogmios.ChainSync.handle_block/2`.
  See `ChainSyncClient` on this project's README for an example.
  """
  def start_chain_sync_link(client, opts) do
    ChainSync.start_link(client, opts)
  end

  @doc """
  Starts a new Tx Submission process linked to the current process.

  `opts` are be passed to the underlying GenServer.
  """
  def start_tx_submission_link(client, opts) do
    TxSubmission.start_link(client, opts)
  end

  @doc """
  Starts a new MempoolTxs (Transactions) process linked to the current process.

  `opts` as keyword lists are passed to the underlying :banana_websocket_client.

  The `:include_details` flag can be used to determine the level of details
  to be returned with each transaction as part of `c:Xogmios.MempoolTxs.handle_transaction/2`.

  Setting this option to `false` (default) means only transaction id is returned:

  ```
  Xogmios.start_mempool_txs_link(__MODULE__, url: ogmios_url, include_details: false)
  ```

  Setting it to `true` means all transaction fields are returned:

  ```
  Xogmios.start_mempool_txs_link(__MODULE__, url: ogmios_url, include_details: true)
  ```
  """
  def start_mempool_txs_link(client, opts) do
    MempoolTxs.start_link(client, opts)
  end

  defmacro __using__(:state_query) do
    quote do
      use Xogmios.StateQuery
    end
  end

  defmacro __using__(:chain_sync) do
    quote do
      use Xogmios.ChainSync
    end
  end

  defmacro __using__(:tx_submission) do
    quote do
      use Xogmios.TxSubmission
    end
  end

  defmacro __using__(:mempool_txs) do
    quote do
      use Xogmios.MempoolTxs
    end
  end

  defmacro __using__(_opts) do
    quote do
      raise "Unsupported method"
    end
  end
end
