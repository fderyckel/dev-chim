defmodule Chimwemwe.AuthDemo.Admin do
  @moduledoc false

  require Ash.Query

  alias Chimwemwe.AuthDemo.Config
  alias Chimwemwe.Identity.{Account, LocalCredentials, SsoConnection}

  @accepted_fields ~w(name protocol issuer_url client_id secret_reference allowed_domains)a

  @spec list(Account.t()) :: {:ok, [SsoConnection.t()]} | {:error, term()}
  def list(account) do
    if authorized?(account) do
      Ash.read(SsoConnection,
        action: :list_for_institution,
        actor: account,
        tenant: Config.tenant_id()
      )
    else
      {:error, :forbidden}
    end
  end

  @spec list_local_accounts(Account.t()) :: {:ok, list()} | {:error, term()}
  def list_local_accounts(account),
    do: if(authorized?(account), do: LocalCredentials.list(), else: {:error, :forbidden})

  @spec provision_local_account(Account.t(), map()) :: {:ok, map()} | {:error, term()}
  def provision_local_account(account, attributes) when is_map(attributes) do
    actor_id = Map.get(attributes, "actor_id")
    email = Map.get(attributes, "email")

    if authorized?(account) and staff_candidate?(actor_id) and is_binary(email) do
      LocalCredentials.provision(email, actor_id)
    else
      {:error, :forbidden}
    end
  end

  def provision_local_account(_account, _attributes), do: {:error, :invalid_input}

  @spec reissue_local_account(Account.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def reissue_local_account(account, account_id) do
    if authorized?(account) and account.id != account_id,
      do: LocalCredentials.reissue(account_id),
      else: {:error, :forbidden}
  end

  @spec suspend_local_account(Account.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def suspend_local_account(account, account_id) do
    if authorized?(account) and account.id != account_id,
      do: LocalCredentials.suspend(account_id),
      else: {:error, :forbidden}
  end

  @spec authorized?(term()) :: boolean()
  def authorized?(%{actor_id: actor_id, status: :active}), do: actor_id == Config.admin_actor_id()
  def authorized?(_account), do: false

  @spec register(Account.t(), map()) :: {:ok, SsoConnection.t()} | {:error, term()}
  def register(account, attributes) when is_map(attributes) do
    if authorized?(account) do
      SsoConnection
      |> Ash.Changeset.for_create(:register_connection, permitted_attributes(attributes))
      |> Ash.create(actor: account, tenant: Config.tenant_id())
    else
      {:error, :forbidden}
    end
  end

  @spec activate(Account.t(), String.t()) :: {:ok, SsoConnection.t()} | {:error, term()}
  def activate(account, connection_id) do
    with true <- authorized?(account),
         {:ok, connection} <- get(account, connection_id) do
      connection
      |> Ash.Changeset.for_update(:activate_connection, %{})
      |> Ash.update(actor: account, tenant: Config.tenant_id())
    else
      false -> {:error, :forbidden}
      {:error, error} -> {:error, error}
    end
  end

  @spec disable(Account.t(), String.t()) :: {:ok, SsoConnection.t()} | {:error, term()}
  def disable(account, connection_id) do
    with true <- authorized?(account),
         {:ok, connection} <- get(account, connection_id) do
      connection
      |> Ash.Changeset.for_update(:disable_connection, %{})
      |> Ash.update(actor: account, tenant: Config.tenant_id())
    else
      false -> {:error, :forbidden}
      {:error, error} -> {:error, error}
    end
  end

  defp staff_candidate?(actor_id) do
    Enum.any?(Config.staff_candidates(), &(&1.actor_id == actor_id))
  end

  defp get(account, connection_id) do
    SsoConnection
    |> Ash.Query.for_read(:list_for_institution)
    |> Ash.Query.filter(id == ^connection_id)
    |> Ash.read_one(actor: account, tenant: Config.tenant_id())
    |> case do
      {:ok, nil} -> {:error, :not_found}
      {:ok, connection} -> {:ok, connection}
      {:error, error} -> {:error, error}
    end
  end

  defp permitted_attributes(attributes) do
    Enum.reduce(@accepted_fields, %{}, fn field, accepted ->
      case Map.fetch(attributes, Atom.to_string(field)) do
        {:ok, value} when is_binary(value) -> Map.put(accepted, field, value)
        _missing_or_invalid -> accepted
      end
    end)
  end
end
