defmodule Xogmios.StateQueryMessageTest do
  use ExUnit.Case

  alias Xogmios.StateQuery.Messages

  test "builds message with no params" do
    json = Messages.build_message("scope", "name", %{})

    message = Jason.decode!(json)

    assert message["params"] == nil
  end

  test "builds message with params" do
    params = %{"addresses" => ["addr_test1123"]}

    json = Messages.build_message("scope", "name", params)

    message = Jason.decode!(json)
    assert message["params"] == params
  end
end
