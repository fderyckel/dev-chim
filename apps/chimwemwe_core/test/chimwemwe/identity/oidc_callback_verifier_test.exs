defmodule Chimwemwe.Identity.TestOidcSecretResolver do
  @behaviour Chimwemwe.Identity.OidcSecretResolver

  alias Chimwemwe.Identity.Error

  @impl true
  def fetch_secret("identity/test/oidc-client"), do: {:ok, "qualified-test-client-secret"}
  def fetch_secret(_reference), do: {:error, %Error{code: :retryable_dependency}}
end

defmodule Chimwemwe.Identity.TestOidcHttpAdapter do
  @behaviour Assent.HTTPAdapter

  alias Assent.HTTPAdapter.HTTPResponse

  @impl true
  def request(method, url, body, headers, _options) do
    send(Application.fetch_env!(:chimwemwe_core, :oidc_test_owner), {
      :oidc_http,
      method,
      url,
      body,
      headers
    })

    case {method, url} do
      {:get, "https://identity.example.test/issuer/.well-known/openid-configuration"} ->
        response(discovery())

      {:post, "https://identity.example.test/token"} ->
        if Application.get_env(:chimwemwe_core, :oidc_test_token_status, 200) == 503 do
          response(%{"error" => "temporarily_unavailable"}, 503)
        else
          response(%{
            "access_token" => "discarded-access-token",
            "id_token" => Application.fetch_env!(:chimwemwe_core, :oidc_test_id_token),
            "token_type" => "Bearer"
          })
        end

      {:get, "https://identity.example.test/jwks"} ->
        response(%{"keys" => [Application.fetch_env!(:chimwemwe_core, :oidc_test_public_key)]})

      _other ->
        response(%{"error" => "not_found"}, 404)
    end
  end

  defp discovery do
    %{
      "authorization_endpoint" => "https://identity.example.test/authorize",
      "code_challenge_methods_supported" => ["S256"],
      "id_token_signing_alg_values_supported" => ["RS256"],
      "issuer" =>
        Application.get_env(
          :chimwemwe_core,
          :oidc_test_discovery_issuer,
          "https://identity.example.test/issuer"
        ),
      "jwks_uri" => "https://identity.example.test/jwks",
      "token_endpoint" => "https://identity.example.test/token",
      "token_endpoint_auth_methods_supported" => ["client_secret_basic"]
    }
  end

  defp response(body, status \\ 200) do
    {:ok,
     %HTTPResponse{
       status: status,
       headers: [{"content-type", "application/json"}],
       body: Jason.encode!(body)
     }}
  end
end

defmodule Chimwemwe.Identity.OidcCallbackVerifierTest do
  use ExUnit.Case, async: false

  alias Chimwemwe.Identity.{
    EnvironmentOidcSecretResolver,
    Error,
    OidcCallbackVerifier,
    VerifiedExternalIdentity
  }

  alias Chimwemwe.Identity.{TestOidcHttpAdapter, TestOidcSecretResolver}
  alias Ecto.UUID

  setup do
    previous_verifier = Application.get_env(:chimwemwe_core, :oidc_verifier)
    private_key = JOSE.JWK.generate_key({:rsa, 2048})
    {_metadata, public_key} = private_key |> JOSE.JWK.to_public() |> JOSE.JWK.to_map()

    Application.put_env(:chimwemwe_core, :oidc_verifier,
      http_adapter: TestOidcHttpAdapter,
      secret_resolver: TestOidcSecretResolver
    )

    Application.put_env(:chimwemwe_core, :oidc_test_owner, self())

    Application.put_env(
      :chimwemwe_core,
      :oidc_test_public_key,
      Map.put(public_key, "kid", "test-key")
    )

    Application.delete_env(:chimwemwe_core, :oidc_test_discovery_issuer)
    Application.delete_env(:chimwemwe_core, :oidc_test_token_status)

    on_exit(fn ->
      if previous_verifier do
        Application.put_env(:chimwemwe_core, :oidc_verifier, previous_verifier)
      else
        Application.delete_env(:chimwemwe_core, :oidc_verifier)
      end

      for key <- [
            :oidc_test_owner,
            :oidc_test_public_key,
            :oidc_test_id_token,
            :oidc_test_discovery_issuer,
            :oidc_test_token_status
          ] do
        Application.delete_env(:chimwemwe_core, key)
      end
    end)

    {:ok, private_key: private_key}
  end

  test "emits S256 and verifies a signed, fresh, allowlisted OIDC result", fixture do
    connection = connection()
    state = Base.url_encode64(:crypto.strong_rand_bytes(48), padding: false)
    context = oidc_context()

    assert {:ok, authorization_url} =
             OidcCallbackVerifier.authorization_url(state, connection, context)

    query = authorization_url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
    assert query["state"] == state
    assert query["nonce"] == context.nonce
    assert query["scope"] == "openid"
    assert query["max_age"] == "600"
    assert query["code_challenge_method"] == "S256"

    assert query["code_challenge"] ==
             :crypto.hash(:sha256, context.code_verifier)
             |> Base.url_encode64(padding: false)

    Application.put_env(
      :chimwemwe_core,
      :oidc_test_id_token,
      signed_token(fixture.private_key, context.nonce)
    )

    callback_context = %{
      connection: connection,
      oidc: Map.put(context, :state, state)
    }

    assert {:ok,
            %VerifiedExternalIdentity{
              connection_id: connection_id,
              protocol: :oidc,
              issuer: "https://identity.example.test/issuer",
              subject: "educator-42",
              assurance: "mfa"
            } = proof} =
             OidcCallbackVerifier.verify_code(
               "single-use-provider-code",
               connection.id,
               callback_context
             )

    assert connection_id == connection.id
    assert DateTime.diff(DateTime.utc_now(), proof.authenticated_at, :second) in 0..5
    refute inspect(proof) =~ "discarded-access-token"

    assert_receive {:oidc_http, :post, "https://identity.example.test/token", body, headers}
    token_params = URI.decode_query(body)
    assert token_params["code"] == "single-use-provider-code"
    assert token_params["code_verifier"] == context.code_verifier
    assert token_params["redirect_uri"] == context.redirect_uri

    assert {"authorization", "Basic " <> encoded_credentials} =
             List.keyfind(headers, "authorization", 0)

    assert Base.decode64!(encoded_credentials) ==
             "selected-educator-client:qualified-test-client-secret"

    refute body =~ "qualified-test-client-secret"
  end

  test "rejects bad nonce, stale authentication, and unallowlisted assurance", fixture do
    connection = connection()
    state = String.duplicate("s", 48)
    context = oidc_context()
    callback_context = %{connection: connection, oidc: Map.put(context, :state, state)}

    Application.put_env(
      :chimwemwe_core,
      :oidc_test_id_token,
      signed_token(fixture.private_key, "wrong-nonce")
    )

    assert {:error, %Error{code: :forbidden}} =
             OidcCallbackVerifier.verify_code("bad-nonce", connection.id, callback_context)

    Application.put_env(
      :chimwemwe_core,
      :oidc_test_id_token,
      signed_token(fixture.private_key, context.nonce, auth_time: System.os_time(:second) - 601)
    )

    assert {:error, %Error{code: :forbidden}} =
             OidcCallbackVerifier.verify_code(
               "stale-authentication",
               connection.id,
               callback_context
             )

    Application.put_env(
      :chimwemwe_core,
      :oidc_test_id_token,
      signed_token(fixture.private_key, context.nonce, acr: "urn:unapproved")
    )

    assert {:error, %Error{code: :forbidden}} =
             OidcCallbackVerifier.verify_code(
               "unmapped-assurance",
               connection.id,
               callback_context
             )
  end

  test "fails closed for changed discovery, connection version, and provider outage", fixture do
    connection = connection()
    state = String.duplicate("s", 48)
    context = oidc_context()

    Application.put_env(
      :chimwemwe_core,
      :oidc_test_discovery_issuer,
      "https://attacker.example.test/issuer"
    )

    assert {:error, %Error{code: :retryable_dependency}} =
             OidcCallbackVerifier.authorization_url(state, connection, context)

    Application.delete_env(:chimwemwe_core, :oidc_test_discovery_issuer)

    assert {:error, %Error{code: :forbidden}} =
             OidcCallbackVerifier.verify_code("version-changed", connection.id, %{
               connection: %{connection | configuration_version: 2},
               oidc: Map.put(context, :state, state)
             })

    Application.put_env(
      :chimwemwe_core,
      :oidc_test_id_token,
      signed_token(fixture.private_key, context.nonce)
    )

    Application.put_env(:chimwemwe_core, :oidc_test_token_status, 503)

    assert {:error, %Error{code: :retryable_dependency}} =
             OidcCallbackVerifier.verify_code("provider-outage", connection.id, %{
               connection: connection,
               oidc: Map.put(context, :state, state)
             })
  end

  test "resolves only the exact deployment-owned secret reference" do
    previous_reference = System.get_env("CHIMWEMWE_OIDC_SECRET_REFERENCE")
    previous_secret = System.get_env("CHIMWEMWE_OIDC_CLIENT_SECRET")

    try do
      System.put_env("CHIMWEMWE_OIDC_SECRET_REFERENCE", "identity/school/educator")
      System.put_env("CHIMWEMWE_OIDC_CLIENT_SECRET", "deployment-owned-secret")

      assert {:ok, "deployment-owned-secret"} =
               EnvironmentOidcSecretResolver.fetch_secret("identity/school/educator")

      assert {:error, %Error{code: :retryable_dependency}} =
               EnvironmentOidcSecretResolver.fetch_secret("identity/other/client")

      System.put_env("CHIMWEMWE_OIDC_CLIENT_SECRET", "too-short")

      assert {:error, %Error{code: :retryable_dependency}} =
               EnvironmentOidcSecretResolver.fetch_secret("identity/school/educator")
    after
      restore_environment("CHIMWEMWE_OIDC_SECRET_REFERENCE", previous_reference)
      restore_environment("CHIMWEMWE_OIDC_CLIENT_SECRET", previous_secret)
    end
  end

  defp connection do
    %{
      id: UUID.generate(),
      issuer: "https://identity.example.test/issuer",
      application_identifier: "selected-educator-client",
      secret_reference: "identity/test/oidc-client",
      assurance_mapping: %{"urn:school:mfa" => "mfa"},
      configuration_version: 1
    }
  end

  defp oidc_context do
    %{
      code_verifier: Base.url_encode64(:crypto.strong_rand_bytes(72), padding: false),
      configuration_version: 1,
      nonce: Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false),
      redirect_uri: "https://app.example.test/auth/callback"
    }
  end

  defp signed_token(private_key, nonce, overrides \\ []) do
    now = System.os_time(:second)

    claims = %{
      "acr" => Keyword.get(overrides, :acr, "urn:school:mfa"),
      "aud" => "selected-educator-client",
      "auth_time" => Keyword.get(overrides, :auth_time, now),
      "exp" => now + 300,
      "iat" => now,
      "iss" => "https://identity.example.test/issuer",
      "nonce" => nonce,
      "sub" => "educator-42"
    }

    private_key
    |> JOSE.JWT.sign(%{"alg" => "RS256", "kid" => "test-key"}, claims)
    |> JOSE.JWS.compact()
    |> elem(1)
  end

  defp restore_environment(name, nil), do: System.delete_env(name)
  defp restore_environment(name, value), do: System.put_env(name, value)
end
