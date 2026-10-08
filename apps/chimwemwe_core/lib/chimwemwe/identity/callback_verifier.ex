defmodule Chimwemwe.Identity.CallbackVerifier do
  @moduledoc """
  Contract implemented by a qualified provider-neutral callback adapter.

  The adapter owns protocol validation, including PKCE, nonce, issuer,
  audience, signature, expiry, state, redirect, replay, and assurance mapping.
  It returns only normalized `VerifiedExternalIdentity` evidence.
  """

  alias Chimwemwe.Identity.{Error, VerifiedExternalIdentity}

  @callback verify_code(code :: String.t(), expected_connection_id :: String.t()) ::
              {:ok, VerifiedExternalIdentity.t()} | {:error, Error.t()}

  @callback authorization_url(
              state :: String.t(),
              connection :: map(),
              oidc_context :: map()
            ) :: {:ok, String.t()} | {:error, Error.t()}

  @callback verify_code(
              code :: String.t(),
              expected_connection_id :: String.t(),
              context :: map()
            ) :: {:ok, VerifiedExternalIdentity.t()} | {:error, Error.t()}

  @optional_callbacks authorization_url: 3, verify_code: 3
end
