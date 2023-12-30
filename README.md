# Xogmios

An Elixir client for [Ogmios](https://github.com/CardanoSolutions/ogmios)

## Running

Populate `OGMIOS_URL` and run the following to start following the chain and printing newly minted blocks as they become available:

```shell
OGMIOS_URL="ws://..." mix run -e "Xogmios.chain_sync" --no-halt
connected!
Finding intersection...

Intersection found.
Waiting for next block...

New Block!
Height: 9739937 ID: 1a13643c99270355251808eec434f99f2ac439971b88b9afda5b055752b546b2

New Block!
Height: 9739938 ID: eba6cfb41f2e1c777ec282b24ea27cf23d118d4522fd26397d8f4b179ea70340

...
```

## Development

This library is highly experimental. It currently only partially supports the chain sync Ouroboros mini-protocol.