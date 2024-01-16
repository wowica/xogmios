# Xogmios

![CI Status](https://github.com/wowica/xogmios/actions/workflows/ci.yml/badge.svg)

An Elixir client for Cardano's [Ogmios](https://github.com/CardanoSolutions/ogmios).

Currently supports the **Chain Synchronization** and **State Query** Ouroboros mini-protocol.

## Installing

Add the dependency to `mix.exs`:

```elixir
defp deps do
  [
    {:xogmios, git: "https://github.com/wowica/xogmios"}
  ]
end
```

## Examples

From a new module, call `use Xogmios.ChainSync` and implement the `start_link/1` and `handle_block/2` functions as such:

```elixir
defmodule MyApp.ChainSyncClient do
  @moduledoc """
  This module syncs with the tip of the chain and reads blocks indefinitely
  """

  use Xogmios.ChainSync

  def start_link(opts),
    do: start_connection(opts)

  @impl true
  def handle_block(block, state) do
    IO.puts("handle_block #{block["height"]}")
    {:ok, :next_block, state}
  end
end
```

Add the new module to your app's supervision tree in `application.ex`:

```elixir
def start(_type, _args) do
  children =[
    {MyApp.ChainSyncClient, url: "ws://url-for-ogmios"},
  ]

  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

The example below syncs with the tip and prints the next 3 blocks:

```elixir
defmodule MyApp.ChainSyncClient do
  @moduledoc """
  This module syncs with the tip of the chain and reads the following 3 blocks
  """

  use Xogmios.ChainSync

  require Logger

  def start_link(opts) do
    # Initial state currently has to be defined here
    # and passed as argument to start_connection
    initial_state = [counter: 3]

    opts
    |> Keyword.merge(initial_state)
    |> start_connection()
  end

  @impl true
  def handle_block(block, %{counter: counter} = state) when counter > 1 do
    Logger.info("handle_block #{block["height"]}")
    {:ok, :next_block, %{state | counter: counter - 1}}
  end

  @impl true
  def handle_block(block, state) do
    Logger.info("final handle_block #{block["height"]}")
    {:ok, :close, state}
  end
end
```

See more examples in the [examples](./examples/) folder.

## Test

Run `mix test`. Tests do not rely on a running OGMIOS instance.

