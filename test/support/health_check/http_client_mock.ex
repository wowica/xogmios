defmodule Xogmios.HealthCheck.HTTPClientMock do
  @moduledoc """
  Mocks the health check response. This module is used in tests.
  """
  def request(:get, _url, _options, _profile), do: {:ok, {{"", 200, ""}, [], []}}
end
