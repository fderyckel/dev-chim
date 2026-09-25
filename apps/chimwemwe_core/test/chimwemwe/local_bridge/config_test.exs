defmodule Chimwemwe.LocalBridge.ConfigTest do
  use ExUnit.Case, async: true

  alias Chimwemwe.LocalBridge.Config

  @valid_token String.duplicate("local-token-", 4)

  test "stays disabled unless local bridge mode is explicitly enabled" do
    assert :disabled = Config.parse(%{})
    assert :disabled = Config.parse(%{"CHIMWEMWE_UI1_LOCAL" => "false"})
  end

  test "requires a sufficiently strong ephemeral token" do
    assert {:error, :bridge_token} =
             Config.parse(%{"CHIMWEMWE_UI1_LOCAL" => "true"})

    assert {:error, :bridge_token} =
             Config.parse(%{
               "CHIMWEMWE_UI1_LOCAL" => "true",
               "CHIMWEMWE_UI1_BRIDGE_TOKEN" => "too-short"
             })

    assert {:ok, options} =
             Config.parse(%{
               "CHIMWEMWE_UI1_LOCAL" => "true",
               "CHIMWEMWE_UI1_BRIDGE_TOKEN" => @valid_token
             })

    assert options[:token] == @valid_token
    assert options[:port] == 4001
  end

  test "rejects invalid ports and accepts an explicit loopback port" do
    base = %{
      "CHIMWEMWE_UI1_LOCAL" => "true",
      "CHIMWEMWE_UI1_BRIDGE_TOKEN" => @valid_token
    }

    assert {:error, :port} = Config.parse(Map.put(base, "CHIMWEMWE_UI1_PORT", "0"))
    assert {:error, :port} = Config.parse(Map.put(base, "CHIMWEMWE_UI1_PORT", "public"))

    assert {:ok, options} = Config.parse(Map.put(base, "CHIMWEMWE_UI1_PORT", "4011"))
    assert options[:port] == 4011
  end
end
