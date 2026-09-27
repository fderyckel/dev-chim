defmodule Chimwemwe.Identity.Token do
  @moduledoc false

  use Ash.Resource,
    otp_app: :chimwemwe_core,
    domain: Chimwemwe.Identity,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table "identity_tokens"
    repo(Chimwemwe.Repo)
  end

  actions do
    defaults [:read]
  end
end
