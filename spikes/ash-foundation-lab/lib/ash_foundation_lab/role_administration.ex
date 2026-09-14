defmodule AshFoundationLab.RoleAdministration do
  @moduledoc """
  Disposable Phase 0 proof for governed, cycle-safe tenant role administration.

  This application-service boundary is deliberately spike-local. It proves named
  actions, tenant serialization, database-backed graph integrity, and atomic audit
  and outbox facts without defining a production role-management API.
  """

  alias AshFoundationLab.AccessControl
  alias AshFoundationLab.Repo
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  @manage_capability "role.manage"

  defmodule TrustedContext do
    @moduledoc """
    Actor, tenant, and correlation identity established before request data reaches the action.
    """

    @enforce_keys [:tenant_id, :actor, :correlation_id]
    defstruct [:tenant_id, :actor, :correlation_id]
  end

  @doc "Renames tenant-defined role data through an optimistic named action."
  def rename_role(context, role_id, new_name, expected_version, opts \\ []) do
    with :ok <- validate_context(context),
         {:ok, role_id} <- cast_uuid(role_id, :role_not_found),
         {:ok, new_name} <- validate_role_name(new_name),
         :ok <- validate_expected_version(expected_version),
         :ok <- authorize(context) do
      transaction(fn ->
        rename_transaction(context, role_id, new_name, expected_version, opts)
      end)
    end
  end

  @doc "Adds a tenant-scoped role inclusion while rejecting direct, indirect, and racing cycles."
  def include_role(context, role_id, included_role_id, opts \\ []) do
    with :ok <- validate_context(context),
         {:ok, role_id} <- cast_uuid(role_id, :role_not_found),
         {:ok, included_role_id} <- cast_uuid(included_role_id, :role_not_found),
         :ok <- authorize(context) do
      transaction(fn -> include_role_transaction(context, role_id, included_role_id, opts) end)
    end
  end

  defp rename_transaction(context, role_id, new_name, expected_version, opts) do
    with {:ok, role} <- lock_role(context.tenant_id, role_id),
         :ok <- require_version(role, expected_version),
         {:ok, next_version} <- persist_rename(context.tenant_id, role_id, new_name),
         :ok <-
           insert_event_pair(context, role_id, nil, "role.renamed", %{
             "lock_version" => next_version
           }),
         :ok <- maybe_fail_after_event(opts) do
      {:ok, %{id: role_id, name: new_name, lock_version: next_version}}
    end
  end

  defp include_role_transaction(context, role_id, included_role_id, opts) do
    with :ok <- lock_tenant_graph(context.tenant_id),
         :ok <- run_graph_lock_hook(opts),
         :ok <- require_roles(context.tenant_id, role_id, included_role_id),
         :ok <- persist_inclusion(context.tenant_id, role_id, included_role_id),
         :ok <-
           insert_event_pair(
             context,
             role_id,
             included_role_id,
             "role.inclusion_added",
             %{}
           ),
         :ok <- maybe_fail_after_event(opts) do
      {:ok, %{role_id: role_id, included_role_id: included_role_id}}
    end
  end

  defp validate_context(%TrustedContext{
         tenant_id: tenant_id,
         actor: %{id: actor_id, tenant_id: actor_tenant_id},
         correlation_id: correlation_id
       }) do
    with {:ok, _tenant_id} <- cast_uuid(tenant_id, :missing_context),
         {:ok, _actor_id} <- cast_uuid(actor_id, :missing_context),
         {:ok, _correlation_id} <- cast_uuid(correlation_id, :missing_context),
         true <- tenant_id == actor_tenant_id do
      :ok
    else
      false -> {:error, :actor_tenant_mismatch}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_context(_context), do: {:error, :missing_context}

  defp validate_role_name(name) when is_binary(name) do
    name = String.trim(name)

    if name != "" and String.length(name) <= 120 do
      {:ok, name}
    else
      {:error, :invalid_role_name}
    end
  end

  defp validate_role_name(_name), do: {:error, :invalid_role_name}

  defp validate_expected_version(version) when is_integer(version) and version >= 1, do: :ok
  defp validate_expected_version(_version), do: {:error, :invalid_role_version}

  defp authorize(context) do
    if AccessControl.actor_has_capability?(context.actor, @manage_capability) do
      :ok
    else
      {:error, :actor_unauthorized}
    end
  end

  defp transaction(operation) do
    case Repo.transaction(fn -> unwrap_transaction_result(operation.()) end) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp unwrap_transaction_result({:ok, result}), do: result
  defp unwrap_transaction_result({:error, reason}), do: Repo.rollback(reason)

  defp lock_role(tenant_id, role_id) do
    case Repo.query!(
           """
           SELECT id::text, lock_version
           FROM roles
           WHERE tenant_id = $1 AND id = $2
           FOR UPDATE
           """,
           [dump_uuid(tenant_id), dump_uuid(role_id)]
         ).rows do
      [[id, lock_version]] -> {:ok, %{id: id, lock_version: lock_version}}
      [] -> {:error, :role_not_found}
    end
  end

  defp require_version(%{lock_version: expected_version}, expected_version), do: :ok
  defp require_version(_role, _expected_version), do: {:error, :role_version_conflict}

  defp persist_rename(tenant_id, role_id, new_name) do
    case Repo.query(
           """
           UPDATE roles
           SET name = $1, lock_version = lock_version + 1, updated_at = NOW()
           WHERE tenant_id = $2 AND id = $3
           RETURNING lock_version
           """,
           [new_name, dump_uuid(tenant_id), dump_uuid(role_id)]
         ) do
      {:ok, %{rows: [[next_version]]}} -> {:ok, next_version}
      {:error, error} -> {:error, translate_postgres_error(error)}
    end
  end

  defp lock_tenant_graph(tenant_id) do
    Repo.query!(
      "SELECT pg_advisory_xact_lock(hashtextextended('role-inclusions:' || $1::text, 0))",
      [tenant_id]
    )

    :ok
  end

  defp require_roles(tenant_id, role_id, included_role_id) do
    role_ids = Enum.uniq([role_id, included_role_id])

    case Repo.query!(
           """
           SELECT count(*)
           FROM roles
           WHERE tenant_id = $1 AND id = ANY($2::uuid[])
           """,
           [dump_uuid(tenant_id), Enum.map(role_ids, &dump_uuid/1)]
         ).rows do
      [[count]] when count == length(role_ids) -> :ok
      _rows -> {:error, :role_not_found}
    end
  end

  defp persist_inclusion(tenant_id, role_id, included_role_id) do
    case Repo.query(
           """
           INSERT INTO role_inclusions (
             id, tenant_id, role_id, included_role_id, inserted_at, updated_at
           )
           VALUES ($1, $2, $3, $4, NOW(), NOW())
           """,
           [
             dump_uuid(UUID.generate()),
             dump_uuid(tenant_id),
             dump_uuid(role_id),
             dump_uuid(included_role_id)
           ]
         ) do
      {:ok, _result} -> :ok
      {:error, error} -> {:error, translate_postgres_error(error)}
    end
  end

  defp insert_event_pair(context, role_id, related_role_id, event_type, payload) do
    action_reference = UUID.generate()

    Enum.reduce_while(["audit", "outbox"], :ok, fn channel, :ok ->
      case Repo.query(
             """
             INSERT INTO role_administration_events (
               id,
               tenant_id,
               role_id,
               related_role_id,
               actor_id,
               action_reference,
               correlation_id,
               channel,
               event_type,
               classification,
               payload,
               inserted_at
             )
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'internal', $10::jsonb, NOW())
             """,
             [
               dump_uuid(UUID.generate()),
               dump_uuid(context.tenant_id),
               dump_uuid(role_id),
               maybe_dump_uuid(related_role_id),
               dump_uuid(context.actor.id),
               dump_uuid(action_reference),
               dump_uuid(context.correlation_id),
               channel,
               event_type,
               payload
             ]
           ) do
        {:ok, _result} -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, translate_postgres_error(error)}}
      end
    end)
  end

  defp run_graph_lock_hook(opts) do
    case Keyword.get(opts, :after_graph_lock) do
      nil -> :ok
      hook when is_function(hook, 0) -> hook.()
      _hook -> {:error, :invalid_graph_lock_hook}
    end
  end

  defp maybe_fail_after_event(opts) do
    if Keyword.get(opts, :inject_event_failure?, false) do
      {:error, :injected_event_failure}
    else
      :ok
    end
  end

  defp translate_postgres_error(%PostgrexError{postgres: %{constraint: constraint}})
       when constraint in ["role_inclusions_acyclic", :role_inclusions_acyclic],
       do: :role_cycle

  defp translate_postgres_error(%PostgrexError{postgres: %{constraint: constraint}})
       when constraint in [
              "role_inclusions_tenant_id_role_id_included_role_id_index",
              :role_inclusions_tenant_id_role_id_included_role_id_index
            ],
       do: :role_inclusion_exists

  defp translate_postgres_error(%PostgrexError{postgres: %{constraint: constraint}})
       when constraint in ["roles_tenant_id_name_index", :roles_tenant_id_name_index],
       do: :role_name_conflict

  defp translate_postgres_error(_error), do: :database_constraint

  defp cast_uuid(value, reason) do
    case UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, reason}
    end
  end

  defp maybe_dump_uuid(nil), do: nil
  defp maybe_dump_uuid(uuid), do: dump_uuid(uuid)
  defp dump_uuid(uuid), do: UUID.dump!(uuid)
end
