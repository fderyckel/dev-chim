defmodule Chimwemwe.Identity.EnvironmentOidcSecretResolver do
  @moduledoc "Resolves the selected OIDC client secret from deployment-owned environment state."

  @behaviour Chimwemwe.Identity.OidcSecretResolver

  alias Chimwemwe.Identity.Error

  @impl true
  def fetch_secret(reference) when is_binary(reference) do
    with expected when is_binary(expected) <-
           System.get_env("CHIMWEMWE_OIDC_SECRET_REFERENCE"),
         true <- byte_size(expected) > 0 and reference == expected,
         secret when is_binary(secret) <- System.get_env("CHIMWEMWE_OIDC_CLIENT_SECRET"),
         true <- byte_size(secret) in 16..4096 do
      {:ok, secret}
    else
      _missing_or_mismatched -> error(:retryable_dependency)
    end
  end

  def fetch_secret(_reference), do: error(:retryable_dependency)

  defp error(code), do: {:error, %Error{code: code}}
end
