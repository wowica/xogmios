defmodule Xogmios.MixProject do
  use Mix.Project

  @description "An Elixir client for Ogmios"
  @source_url "https://github.com/wowica/xogmios"
  @version "0.6.0"

  def project do
    [
      app: :xogmios,
      version: @version,
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:yecc] ++ Mix.compilers(),
      test_coverage: [
        ignore_modules: [
          ~r/\.TestRouter/,
          ~r/\.TestHandler/,
          ~r/\.TestServer/,
          ChainSyncClient,
          StateQueryClient
        ]
      ],
      description: @description,
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :inets, :ssl, :crypto, :public_key, :asn1]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:cowboy, "~> 2.10", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4.1", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:jason, "~> 1.4"},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:plug, "~> 1.15", only: :test},
      {:plug_cowboy, "~> 2.6", only: :test},
      {:banana_websocket_client, "~> 0.0.3"}
    ]
  end

  defp package do
    [
      description: @description,
      licenses: ["Apache-2.0"],
      maintainers: ["Carlos Souza"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      name: "Xogmios",
      source_url: @source_url,
      extras: ["README.md"]
    ]
  end
end
