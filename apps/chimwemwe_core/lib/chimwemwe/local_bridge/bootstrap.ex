defmodule Chimwemwe.LocalBridge.Bootstrap do
  @moduledoc false

  use GenServer

  alias Chimwemwe.LocalBridge.SyntheticData
  alias Chimwemwe.Platform.Persistence
  alias Chimwemwe.Repo

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options), do: GenServer.start_link(__MODULE__, options)

  @impl true
  def init(options) do
    runtime = Keyword.fetch!(options, :runtime)

    with :ok <- seed_tenant(runtime, SyntheticData.tenant_a_context(), :tenant_a),
         :ok <- seed_tenant(runtime, SyntheticData.tenant_b_context(), :tenant_b) do
      {:ok, %{}}
    else
      {:error, reason} -> {:stop, {:local_bridge_seed_failed, reason}}
    end
  end

  defp seed_tenant(runtime, context, tenant_key) do
    rows = SyntheticData.seed_rows()

    tenant_id =
      if tenant_key == :tenant_a, do: SyntheticData.tenant_a(), else: SyntheticData.tenant_b()

    case Persistence.with_writer(runtime, context, fn -> seed_transaction(rows, tenant_id) end) do
      {:ok, {:ok, _result}} -> :ok
      {:ok, {:error, reason}} -> {:error, reason}
      {:error, reason} -> {:error, reason}
    end
  end

  defp seed_transaction(rows, tenant_id) do
    Repo.transaction(fn ->
      seed_memberships(rows.memberships, tenant_id)
      seed_roles(rows.roles, tenant_id)
      seed_capabilities(rows.capabilities, tenant_id)
      seed_assignments(rows.assignments, tenant_id)
      seed_grants(rows.grants, tenant_id)
    end)
  end

  defp seed_memberships(rows, tenant_id) do
    Enum.each(for(row = {_id, ^tenant_id, _actor_id} <- rows, do: row), fn {id, tenant, actor} ->
      Repo.query!(
        """
        INSERT INTO platform_tenant_memberships
          (id, tenant_id, actor_id, inserted_at, updated_at)
        VALUES ($1, $2, $3, NOW(), NOW())
        ON CONFLICT DO NOTHING
        """,
        dump_all([id, tenant, actor])
      )
    end)
  end

  defp seed_roles(rows, tenant_id) do
    Enum.each(for(row = {_id, ^tenant_id, _name} <- rows, do: row), fn {id, tenant, name} ->
      Repo.query!(
        """
        INSERT INTO platform_roles
          (id, tenant_id, name, lock_version, inserted_at, updated_at)
        VALUES ($1, $2, $3, 1, NOW(), NOW())
        ON CONFLICT DO NOTHING
        """,
        [dump(id), dump(tenant), name]
      )
    end)
  end

  defp seed_capabilities(rows, tenant_id) do
    Enum.each(for(row = {_id, ^tenant_id, _key} <- rows, do: row), fn {id, tenant, key} ->
      Repo.query!(
        """
        INSERT INTO platform_capabilities
          (id, tenant_id, key, inserted_at, updated_at)
        VALUES ($1, $2, $3, NOW(), NOW())
        ON CONFLICT DO NOTHING
        """,
        [dump(id), dump(tenant), key]
      )
    end)
  end

  defp seed_assignments(rows, tenant_id) do
    Enum.each(
      for(row = {_id, ^tenant_id, _membership_id, _role_id} <- rows, do: row),
      fn {id, tenant, membership_id, role_id} ->
        Repo.query!(
          """
          INSERT INTO platform_actor_role_assignments
            (id, tenant_id, membership_id, role_id, lock_version, inserted_at)
          VALUES ($1, $2, $3, $4, 1, NOW())
          ON CONFLICT DO NOTHING
          """,
          dump_all([id, tenant, membership_id, role_id])
        )
      end
    )
  end

  defp seed_grants(rows, tenant_id) do
    Enum.each(
      for(row = {_id, ^tenant_id, _role_id, _capability_id} <- rows, do: row),
      fn {id, tenant, role_id, capability_id} ->
        Repo.query!(
          """
          INSERT INTO platform_role_capability_grants
            (id, tenant_id, role_id, capability_id, inserted_at)
          VALUES ($1, $2, $3, $4, NOW())
          ON CONFLICT DO NOTHING
          """,
          dump_all([id, tenant, role_id, capability_id])
        )
      end
    )
  end

  defp dump_all(values), do: Enum.map(values, &dump/1)
  defp dump(value), do: Ecto.UUID.dump!(value)
end
