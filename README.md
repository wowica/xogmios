# Xogmios

![CI Status](https://github.com/wowica/xogmios/actions/workflows/ci.yml/badge.svg)

An Elixir client for [Ogmios](https://github.com/CardanoSolutions/ogmios).  

> Ogmios is a lightweight bridge interface for a Cardano node. It offers a WebSockets API that enables local clients to speak Ouroboros' mini-protocols via JSON/RPC. - https://ogmios.dev/

It currently only partially supports the **Chain Synchronization** and **State Query** mini-protocols. See [Examples](#examples) section below for information on how to use it.

## Installing

Add the dependency to `mix.exs`:

```elixir
defp deps do
  [
    {:xogmios, github: "wowica/xogmios"}
  ]
end
```

Not yet available on Hex.

## Examples

See [ChainSyncClient](./examples/chain_sync_client.ex) and [StateQueryClient](./examples/state_query_client.ex)

## Test

Run `mix test`. Tests do NOT rely on a running Ogmios instance.

