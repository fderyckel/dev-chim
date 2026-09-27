defmodule Chimwemwe.AuthDemo.Bootstrap do
  @moduledoc false

  use GenServer

  alias Chimwemwe.Identity.{Account, SsoConnection}

  @demo_email "identity-admin@northstar-school.test"

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options), do: GenServer.start_link(__MODULE__, options)

  @impl true
  def init(options) do
    password = Keyword.fetch!(options, :password)
    tenant_id = Keyword.fetch!(options, :tenant_id)

    account = seed_account(password)
    seed_connection(account, tenant_id)

    :ignore
  end

  defp seed_account(password) do
    {:ok, hashed_password} = AshAuthentication.BcryptProvider.hash(password)

    case Account
         |> Ash.Query.for_read(:lookup_local_demo_account, %{email: @demo_email})
         |> Ash.read(authorize?: false) do
      {:ok, [account]} ->
        Ash.Changeset.for_update(account, :rotate_local_demo_password, %{
          hashed_password: hashed_password
        })
        |> Ash.update!(authorize?: false)

      {:ok, []} ->
        Ash.Changeset.for_create(Account, :bootstrap_local_account, %{
          email: @demo_email,
          hashed_password: hashed_password,
          status: :active
        })
        |> Ash.create!(authorize?: false)
    end
  end

  defp seed_connection(account, tenant_id) do
    case Ash.read(SsoConnection,
           action: :list_for_institution,
           actor: account,
           tenant: tenant_id
         ) do
      {:ok, []} ->
        SsoConnection
        |> Ash.Changeset.for_create(:register_connection, %{
          name: "Northstar Entra OIDC",
          protocol: :oidc,
          issuer_url: "https://login.microsoftonline.com/synthetic-tenant-id/v2.0",
          client_id: "northstar-synthetic-client",
          secret_reference: "identity/northstar/oidc-client-secret",
          allowed_domains: "northstar-school.test"
        })
        |> Ash.create!(actor: account, tenant: tenant_id)

      {:ok, _connections} ->
        :ok
    end
  end
end
