# Xogmios

![CI Status](https://github.com/wowica/xogmios/actions/workflows/ci.yml/badge.svg)

An Elixir client for [Ogmios](https://github.com/CardanoSolutions/ogmios). This project is highly experimental. It currently only partially supports the chain sync Ouroboros mini-protocol.

## Running as a library

Add the dependency to `mix.exs`:

```elixir
defp deps do
  [
    {:xogmios, git: "https://github.com/wowica/xogmios"}
  ]
end
```

From a new module, call `use Xogmios.ChainSync` and implement the `start_link/1` and `handle_block/2` functions as such:

```elixir
defmodule MyApp.XogmiosClient do

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

Add the new module to the app's supervision tree in `application.ex`:

```elixir
def start(_type, _args) do
  children =[
    {MyApp.XogmiosClient, url: "ws://url-for-ogmios"},
  ]

  opts = [strategy: :one_for_one, name: Xogmios.Supervisor]
  Supervisor.start_link(children, opts)
end
```

See more examples in [Xogmios.ClientExampleA](lib/xogmios/client_example_a.ex) and [Xogmios.ClientExampleB](lib/xogmios/client_example_b.ex)

## Running as a standalone client

Clone this repo, populate `OGMIOS_URL` and run the following to start following the chain and printing newly minted blocks as they become available:  

```shell
OGMIOS_URL="ws://..." mix run --no-halt
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

## Text

Run `mix test`

