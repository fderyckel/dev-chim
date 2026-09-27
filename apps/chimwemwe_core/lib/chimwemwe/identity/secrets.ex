defmodule Chimwemwe.Identity.Secrets do
  @moduledoc false

  use AshAuthentication.Secret

  @impl true
  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Chimwemwe.Identity.Account,
        _options,
        _context
      ) do
    Application.fetch_env(:chimwemwe_core, :identity_token_signing_secret)
  end

  def secret_for(_path, _resource, _options, _context), do: :error
end
