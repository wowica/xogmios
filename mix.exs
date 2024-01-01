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
      extra_applications: [:logger, :observer, :wx, :runtime_tools],
      mod: {Xogmios.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:websockex, "~> 0.4.3"},
      {:cowboy, "~> 2.10", only: :test},
      {:plug, "~> 1.15", only: :test},
      {:plug_cowboy, "~> 2.6", only: :test}
    ]
  end
end
