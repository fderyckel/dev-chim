defmodule Chimwemwe.AuthDemo.Admin do
  @moduledoc false

  require Ash.Query

  alias Chimwemwe.AuthDemo.Config
  alias Chimwemwe.Identity.SsoConnection

  @accepted_fields ~w(name protocol issuer_url client_id secret_reference allowed_domains)a

  @spec list(SsoConnection.t()) :: {:ok, [SsoConnection.t()]} | {:error, term()}
  def list(account) do
    Ash.read(SsoConnection,
      action: :list_for_institution,
      actor: account,
      tenant: Config.tenant_id()
    )
  end

  @spec register(SsoConnection.t(), map()) :: {:ok, SsoConnection.t()} | {:error, term()}
  def register(account, attributes) when is_map(attributes) do
    SsoConnection
    |> Ash.Changeset.for_create(:register_connection, permitted_attributes(attributes))
    |> Ash.create(actor: account, tenant: Config.tenant_id())
  end

  @spec activate(SsoConnection.t(), String.t()) :: {:ok, SsoConnection.t()} | {:error, term()}
  def activate(account, connection_id) do
    with {:ok, connection} <- get(account, connection_id) do
      connection
      |> Ash.Changeset.for_update(:activate_connection, %{})
      |> Ash.update(actor: account, tenant: Config.tenant_id())
    end
  end

  @spec disable(SsoConnection.t(), String.t()) :: {:ok, SsoConnection.t()} | {:error, term()}
  def disable(account, connection_id) do
    with {:ok, connection} <- get(account, connection_id) do
      connection
      |> Ash.Changeset.for_update(:disable_connection, %{})
      |> Ash.update(actor: account, tenant: Config.tenant_id())
    end
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
