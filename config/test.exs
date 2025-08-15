import Config

config :xogmios, Xogmios.HealthCheck, http_client: Xogmios.HealthCheck.HTTPClientMock
config :xogmios, Xogmios.StateQuery.HTTP, http_client: Xogmios.HTTP.ClientMock
