defmodule Xogmios.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      []
      |> Kernel.++(xogmios_websocket())

    opts = [strategy: :one_for_one, name: Xogmios.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def xogmios_websocket() do
    connection_url = System.get_env("OGMIOS_URL")

    if is_nil(connection_url) do
      []
    else
      [
        {Xogmios.ClientExampleA, url: connection_url},
        {Xogmios.ClientExampleB, url: connection_url}
      ]
    end
  end
end
