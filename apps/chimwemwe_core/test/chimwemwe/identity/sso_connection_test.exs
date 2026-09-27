defmodule Chimwemwe.Identity.SsoConnectionTest do
  use ExUnit.Case, async: true

  alias Ash.Resource.Info
  alias Chimwemwe.Identity.SsoConnection

  @base_attributes %{
    name: "Synthetic institution OIDC",
    protocol: :oidc,
    issuer_url: "https://identity.example.test/issuer",
    client_id: "synthetic-client",
    secret_reference: "identity/synthetic/sign-in-secret",
    allowed_domains: "example.test"
  }

  test "models the connection protocol rather than a vendor" do
    assert nil == Info.attribute(SsoConnection, :provider)

    protocol = Info.attribute(SsoConnection, :protocol)

    assert protocol.constraints[:one_of] == [:oidc, :saml]
  end

  test "accepts both provider-neutral sign-in protocols" do
    for protocol <- [:oidc, :saml] do
      changeset =
        SsoConnection
        |> Ash.Changeset.for_create(
          :register_connection,
          Map.put(@base_attributes, :protocol, protocol)
        )

      assert changeset.valid?
    end
  end

  test "rejects a provider name as the protocol" do
    changeset =
      SsoConnection
      |> Ash.Changeset.for_create(
        :register_connection,
        Map.put(@base_attributes, :protocol, :microsoft)
      )

    refute changeset.valid?
  end
end
