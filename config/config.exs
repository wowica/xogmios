import Config

env_config_file = "#{config_env()}.exs"

if File.exists?("config/#{env_config_file}") do
  import_config env_config_file
end
