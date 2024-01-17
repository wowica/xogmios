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

See [ChainSyncClient](./examples/chain_sync_client.ex) and [StateQueryClient](./examples/state_query_client.ex)

## Test

Run `mix test`. Tests do not rely on a running OGMIOS instance.

