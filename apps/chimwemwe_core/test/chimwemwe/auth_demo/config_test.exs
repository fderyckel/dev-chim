defmodule Chimwemwe.AuthDemo.ConfigTest do
  use ExUnit.Case, async: true

  alias Chimwemwe.AuthDemo.Config

  @secret String.duplicate("local-auth-secret-", 3)

  test "stays disabled unless the loopback authentication demo is explicitly enabled" do
    assert :disabled = Config.parse(%{})
    assert :disabled = Config.parse(%{"CHIMWEMWE_AUTH_DEMO" => "false"})
  end

  test "requires sufficiently long ephemeral password and signing secret" do
    assert {:error, :local_secret} = Config.parse(%{"CHIMWEMWE_AUTH_DEMO" => "true"})

    assert {:error, :local_secret} =
             Config.parse(%{
               "CHIMWEMWE_AUTH_DEMO" => "true",
               "CHIMWEMWE_AUTH_DEMO_PASSWORD" => "too-short",
               "CHIMWEMWE_AUTH_TOKEN_SIGNING_SECRET" => @secret
             })

    assert {:error, :local_secret} =
             Config.parse(%{
               "CHIMWEMWE_AUTH_DEMO" => "true",
               "CHIMWEMWE_AUTH_DEMO_PASSWORD" => @secret,
               "CHIMWEMWE_AUTH_TOKEN_SIGNING_SECRET" => "too-short"
             })
  end

  test "rejects concurrent UI-1A use and accepts only a loopback local configuration" do
    environment = %{
      "CHIMWEMWE_AUTH_DEMO" => "true",
      "CHIMWEMWE_AUTH_DEMO_PASSWORD" => @secret,
      "CHIMWEMWE_AUTH_TOKEN_SIGNING_SECRET" => @secret
    }

    assert {:error, :ui1_local_conflict} =
             Config.parse(Map.put(environment, "CHIMWEMWE_UI1_LOCAL", "true"))

    assert {:ok, options} = Config.parse(Map.put(environment, "CHIMWEMWE_AUTH_PORT", "4012"))
    assert options[:port] == 4012
    assert options[:tenant_id] == "99999999-9999-4999-8999-999999999999"
    assert options[:password] == @secret
    assert options[:signing_secret] == @secret
  end

  test "rejects ports outside the local TCP range" do
    environment = %{
      "CHIMWEMWE_AUTH_DEMO" => "true",
      "CHIMWEMWE_AUTH_DEMO_PASSWORD" => @secret,
      "CHIMWEMWE_AUTH_TOKEN_SIGNING_SECRET" => @secret
    }

    assert {:error, :port} = Config.parse(Map.put(environment, "CHIMWEMWE_AUTH_PORT", "0"))
    assert {:error, :port} = Config.parse(Map.put(environment, "CHIMWEMWE_AUTH_PORT", "public"))
  end
end
