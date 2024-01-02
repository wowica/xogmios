defmodule Xogmios.MixProject do
  use Mix.Project

  def project do
    [
      app: :xogmios,
      version: "0.1.0",
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:yecc] ++ Mix.compilers(),
      test_coverage: [
        ignore_modules: [
          ~r/\.TestRouter/,
          ~r/\.TestConnection/,
          ~r/\.TestHandler/,
          ~r/\.TestServer/,
          Xogmios.ClientExampleA,
          Xogmios.ClientExampleB
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
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
      {:jason, "~> 1.4"},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:plug, "~> 1.15", only: :test},
      {:plug_cowboy, "~> 2.6", only: :test},
      {:websockex, "~> 0.4.3"}
    ]
  end
end
