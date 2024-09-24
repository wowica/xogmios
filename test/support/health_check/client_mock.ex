defmodule Xogmios.HealthCheck.ClientMock do
  @moduledoc """
  Mocks the health check call. This module is used in tests.
  """
  def run(_url), do: :ok
end
