defmodule Xogmios.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Xogmios.Websocket, url: ogmios_url()},
      Xogmios.Database
    ]

    opts = [strategy: :one_for_one, name: Xogmios.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp ogmios_url do
    System.fetch_env!("OGMIOS_URL")
  end
end
