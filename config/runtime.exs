import Config

# Set LOGGER_LEVEL env to one of the valid
# values for level https://hexdocs.pm/logger/1.12.3/Logger.html#module-levels
# In order to help with debugging, set LOGGER_LEVEL="debug"
case config_env() do
  :test ->
    config :logger,
      level: System.get_env("LOGGER_LEVEL", "warning") |> String.to_existing_atom()

  _ ->
    config :logger,
      level: System.get_env("LOGGER_LEVEL", "info") |> String.to_existing_atom()
end
