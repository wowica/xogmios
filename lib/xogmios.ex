defmodule Xogmios do
  @moduledoc """
  This is the top level module for Xogmios. It implements functions to be used by client
  modules that wish to connect with Ogmios.

  When used, the it expects one of the supported mini-protocols as argument. For example:

      defmodule ChainSyncClient do
        use Xogmios, :chain_sync
        # ...
      end

  or

      defmodule StateQueryClient do
        use Xogmios, :state_query
        # ...
      end
  """

  alias Xogmios.TxSubmission
  alias Xogmios.ChainSync
  alias Xogmios.StateQuery

  @doc """
  Starts a new State Query process linked to the current process
  """
  def start_state_link(client, opts) do
    StateQuery.start_link(client, opts)
  end

  @doc """
  Starts a new Chain Sync process linked to the current process.

  The `sync_from` option can be passed as part of `opts` to define at which point
  the chain should be synced from.

  This option accepts either:

  a) An atom from the list: `:origin`, `:byron`,
  `:shelley`, `:allegra`, `:mary`, `:alonzo`, `:babbage`.

  For example:

  ```elixir
  def start_link(opts) do
    initial_state = [sync_from: :babbage]
    opts = Keyword.merge(opts, initial_state)
    Xogmios.start_chain_sync_link(__MODULE__, opts)
  end
  ```

  This will sync with the chain starting from the first block of the Babbage era.

  b) A point in the chain, given its `slot` and `id`. For example:

  ```elixir
  def start_link(opts) do
    initial_state = [
      sync_from: %{
        point: %{
          slot: 114_127_654,
          id: "b0ff1e2bfc326a7f7378694b1f2693233058032bfb2798be2992a0db8b143099"
        }
      }
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

  def start_tx_submission_link(client, opts) do
    TxSubmission.start_link(client, opts)
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
end
