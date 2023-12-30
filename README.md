# Xogmios

An Elixir client for [Ogmios](https://github.com/CardanoSolutions/ogmios)

## Running

Populate `OGMIOS_URL` and start iex:

```shell
OGMIOS_URL="ws://..." iex -S mix
```

Then run the following:

```elixir
Xogmios.chain_sync()
```

## Development

This library is highly experimental and is under heavy development. The ultimate goal is to support all of Ouroboros' mini-protocols.