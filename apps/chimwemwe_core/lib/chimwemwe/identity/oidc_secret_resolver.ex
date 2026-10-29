defmodule Chimwemwe.Identity.OidcSecretResolver do
  @moduledoc "Runtime-only resolver contract for one qualified OIDC client secret reference."

  alias Chimwemwe.Identity.Error

  @callback fetch_secret(reference :: String.t()) ::
              {:ok, String.t()} | {:error, Error.t()}
end
