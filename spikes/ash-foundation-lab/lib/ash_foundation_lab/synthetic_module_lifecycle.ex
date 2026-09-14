defmodule AshFoundationLab.SyntheticModuleLifecycle do
  @moduledoc """
  Disposable Phase 0 proof of independent module gates and controlled deactivation.

  This is deliberately a spike-local application boundary, not a production module
  registry or framework API. Trusted release and actor context are supplied by the
  platform side of the boundary; request fields never select those values.
  """

  alias AshFoundationLab.AccessControl
  alias AshFoundationLab.Repo
  alias Ecto.UUID

  @module_key "synthetic.records"
  @use_capability "synthetic_module.use"
  @manage_capability "synthetic_module.manage"
  @mandatory_work_capability "synthetic_module.mandatory_work"

  defmodule TrustedContext do
    @moduledoc """
    Actor and tenant identity established before request data reaches the module boundary.
    """

    @enforce_keys [:tenant_id, :actor, :correlation_id]
    defstruct [:tenant_id, :actor, :correlation_id]
  end

  defmodule ReleaseManifest do
    @moduledoc """
    Immutable stand-in for release-owned module availability and compatibility metadata.
    """

    @enforce_keys [:modules]
    defstruct [:modules]
  end

  @doc "Returns the one neutral module identifier exercised by this spike."
  def module_key, do: @module_key

  @doc "Builds validated release metadata without consulting request parameters."
  def new_release_manifest!(entries) when is_list(entries) do
    modules =
      Enum.reduce(entries, %{}, fn entry, manifest ->
        validate_release_entry!(entry)

        if Map.has_key?(manifest, entry.key) do
          raise ArgumentError, "duplicate release module"
        end

        Map.put(manifest, entry.key, entry)
      end)

    %ReleaseManifest{modules: modules}
  end

  @doc """
  Activates the neutral module through an explicit, optimistic lifecycle transition.

  The request map is accepted only to prove that client-supplied entitlement,
  activation, or tenant fields cannot influence the server-owned gates.
  """
  def activate(context, manifest, expected_version, _request \\ %{}, opts \\ []) do
    with :ok <- validate_context(context),
         {:ok, release} <- released_module(manifest) do
      transaction(fn -> activate_transaction(context, release, expected_version, opts) end)
    end
  end

  @doc """
  Performs the module's only ordinary named action after all four gates pass.

  The fixed `label` argument is the action's allowlist. Extra request fields are not
  read, so they cannot change release, entitlement, activation, actor, or tenant state.
  """
  def revise_retained_record(
        context,
        manifest,
        record_id,
        label,
        expected_version,
        _request \\ %{},
        opts \\ []
      ) do
    with :ok <- validate_context(context),
         :ok <- validate_record_input(record_id, label),
         {:ok, _release} <- released_module(manifest) do
      transaction(fn ->
        revise_transaction(context, record_id, label, expected_version, opts)
      end)
    end
  end

  @doc """
  Closes ordinary authority, parks ordinary work, and preserves mandatory kernel work.
  """
  def deactivate(context, manifest, expected_version, opts \\ []) do
    with :ok <- validate_context(context),
         {:ok, _release} <- released_module(manifest) do
      transaction(fn -> deactivate_transaction(context, expected_version, opts) end)
    end
  end

  @doc """
  Completes explicitly mandatory work without reopening ordinary module authority.
  """
  def complete_mandatory_work(context, work_item_id) do
    with :ok <- validate_context(context),
         {:ok, work_item_id} <- cast_uuid(work_item_id, :work_item_not_found) do
      transaction(fn ->
        complete_mandatory_work_transaction(context, work_item_id)
      end)
    end
  end

  @doc """
  Reactivates only after compatibility, projection rebuild, replay, and reconciliation succeed.
  """
  def reactivate(context, manifest, expected_version, opts \\ []) do
    with :ok <- validate_context(context),
         {:ok, release} <- released_module(manifest) do
      transaction(fn -> reactivate_transaction(context, release, expected_version, opts) end)
    end
  end

  defp activate_transaction(context, release, expected_version, opts) do
    with :ok <- authorize(context, @manage_capability),
         {:ok, instance} <- lock_instance(context.tenant_id),
         :ok <- require_entitlement(instance),
         :ok <- require_dependency(instance),
         :ok <- require_state(instance, "inactive"),
         :ok <- require_version(instance, expected_version),
         :ok <- run_lock_hook(opts) do
      next_version = instance.lifecycle_version + 1

      Repo.query!(
        """
        UPDATE synthetic_module_instances
        SET activation_state = 'active',
            installed_version = $1,
            lifecycle_version = $2,
            projection_ready = true,
            reconciliation_required = false,
            replay_from_cursor = NULL,
            updated_at = NOW()
        WHERE id = $3 AND tenant_id = $4
        """,
        [
          release.version,
          next_version,
          dump_uuid(instance.id),
          dump_uuid(context.tenant_id)
        ]
      )

      insert_event_pair(
        instance,
        context,
        "synthetic_module.activated",
        next_version,
        %{"installed_version" => release.version}
      )

      {:ok, %{activation_state: :active, lifecycle_version: next_version}}
    end
  end

  defp revise_transaction(context, record_id, label, expected_version, opts) do
    with :ok <- authorize(context, @use_capability),
         {:ok, instance} <- lock_instance(context.tenant_id),
         :ok <- require_entitlement(instance),
         :ok <- require_state(instance, "active"),
         :ok <- require_version(instance, expected_version),
         {:ok, record} <- lock_record(context.tenant_id, instance.id, record_id),
         :ok <- run_lock_hook(opts) do
      next_version = instance.lifecycle_version + 1

      Repo.query!(
        """
        UPDATE synthetic_module_records
        SET label = $1, updated_at = NOW()
        WHERE id = $2 AND tenant_id = $3 AND module_instance_id = $4
        """,
        [
          label,
          dump_uuid(record.id),
          dump_uuid(context.tenant_id),
          dump_uuid(instance.id)
        ]
      )

      increment_lifecycle_version(instance, context.tenant_id, next_version)

      insert_event_pair(
        instance,
        context,
        "synthetic_module.record_revised",
        next_version,
        %{"record_id" => record.id}
      )

      {:ok, %{record_id: record.id, label: label, lifecycle_version: next_version}}
    end
  end

  defp deactivate_transaction(context, expected_version, opts) do
    with :ok <- authorize(context, @manage_capability),
         {:ok, instance} <- lock_instance(context.tenant_id),
         :ok <- require_state(instance, "active"),
         :ok <- require_no_active_dependents(instance),
         :ok <- require_version(instance, expected_version),
         :ok <- run_lock_hook(opts) do
      next_version = instance.lifecycle_version + 1

      Repo.query!(
        """
        UPDATE synthetic_module_instances
        SET activation_state = 'inactive',
            lifecycle_version = $1,
            replay_from_cursor = event_cursor,
            projection_ready = false,
            reconciliation_required = true,
            updated_at = NOW()
        WHERE id = $2 AND tenant_id = $3
        """,
        [next_version, dump_uuid(instance.id), dump_uuid(context.tenant_id)]
      )

      %{num_rows: parked_count} =
        Repo.query!(
          """
          UPDATE synthetic_module_work_items
          SET status = 'parked', updated_at = NOW()
          WHERE tenant_id = $1
            AND module_instance_id = $2
            AND work_kind = 'ordinary'
            AND status IN ('queued', 'running')
          """,
          [dump_uuid(context.tenant_id), dump_uuid(instance.id)]
        )

      insert_event_pair(
        instance,
        context,
        "synthetic_module.deactivated",
        next_version,
        %{
          "parked_work_count" => parked_count,
          "replay_from_cursor" => instance.event_cursor
        }
      )

      {:ok,
       %{
         activation_state: :inactive,
         lifecycle_version: next_version,
         parked_work_count: parked_count,
         replay_from_cursor: instance.event_cursor
       }}
    end
  end

  defp complete_mandatory_work_transaction(context, work_item_id) do
    with :ok <- authorize(context, @mandatory_work_capability),
         {:ok, instance} <- lock_instance(context.tenant_id),
         {:ok, work_item} <-
           lock_mandatory_work_item(context.tenant_id, instance.id, work_item_id) do
      Repo.query!(
        """
        UPDATE synthetic_module_work_items
        SET status = 'completed', updated_at = NOW()
        WHERE id = $1 AND tenant_id = $2 AND module_instance_id = $3
        """,
        [
          dump_uuid(work_item.id),
          dump_uuid(context.tenant_id),
          dump_uuid(instance.id)
        ]
      )

      insert_event_pair(
        instance,
        context,
        "synthetic_module.mandatory_work_completed",
        instance.lifecycle_version,
        %{"work_item_id" => work_item.id}
      )

      {:ok, %{work_item_id: work_item.id, status: :completed}}
    end
  end

  defp reactivate_transaction(context, release, expected_version, opts) do
    with :ok <- authorize(context, @manage_capability),
         {:ok, instance} <- lock_instance(context.tenant_id),
         :ok <- require_entitlement(instance),
         :ok <- require_dependency(instance),
         :ok <- require_state(instance, "inactive"),
         :ok <- require_version(instance, expected_version),
         :ok <- require_compatibility(instance, release),
         :ok <- run_lock_hook(opts) do
      next_version = instance.lifecycle_version + 1

      Repo.query!(
        """
        UPDATE synthetic_module_instances
        SET activation_state = 'active',
            installed_version = $1,
            lifecycle_version = $2,
            replay_from_cursor = NULL,
            projection_version = projection_version + 1,
            projection_ready = true,
            reconciliation_required = false,
            updated_at = NOW()
        WHERE id = $3 AND tenant_id = $4
        """,
        [
          release.version,
          next_version,
          dump_uuid(instance.id),
          dump_uuid(context.tenant_id)
        ]
      )

      Repo.query!(
        """
        UPDATE synthetic_module_work_items
        SET status = 'queued', updated_at = NOW()
        WHERE tenant_id = $1
          AND module_instance_id = $2
          AND work_kind = 'ordinary'
          AND status = 'parked'
        """,
        [dump_uuid(context.tenant_id), dump_uuid(instance.id)]
      )

      insert_event_pair(
        instance,
        context,
        "synthetic_module.reactivated",
        next_version,
        %{
          "from_version" => instance.installed_version,
          "to_version" => release.version,
          "replayed_from_cursor" => instance.replay_from_cursor
        }
      )

      maybe_fail_reconciliation(opts)

      {:ok,
       %{
         activation_state: :active,
         installed_version: release.version,
         lifecycle_version: next_version
       }}
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

  defp maybe_fail_reconciliation(opts) do
    if Keyword.get(opts, :inject_reconciliation_failure?, false) do
      Repo.rollback(:reconciliation_failed)
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

  defp validate_record_input(record_id, label) when is_binary(label) and byte_size(label) > 0 do
    case cast_uuid(record_id, :record_not_found) do
      {:ok, _record_id} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_record_input(_record_id, _label), do: {:error, :invalid_action_input}

  defp released_module(%ReleaseManifest{modules: modules}) do
    case Map.fetch(modules, @module_key) do
      {:ok, release} -> {:ok, release}
      :error -> {:error, :module_not_released}
    end
  end

  defp released_module(_manifest), do: {:error, :module_not_released}

  defp authorize(context, capability) do
    if AccessControl.actor_has_capability?(context.actor, capability) do
      :ok
    else
      {:error, :actor_unauthorized}
    end
  end

  defp lock_instance(tenant_id) do
    case Repo.query!(
           """
           SELECT id::text,
                  installed_version,
                  entitled,
                  activation_state,
                  dependency_ready,
                  active_dependents,
                  lifecycle_version,
                  event_cursor,
                  replay_from_cursor,
                  projection_version,
                  projection_ready,
                  reconciliation_required
           FROM synthetic_module_instances
           WHERE tenant_id = $1 AND module_key = $2
           FOR UPDATE
           """,
           [dump_uuid(tenant_id), @module_key]
         ).rows do
      [
        [
          id,
          installed_version,
          entitled,
          activation_state,
          dependency_ready,
          active_dependents,
          lifecycle_version,
          event_cursor,
          replay_from_cursor,
          projection_version,
          projection_ready,
          reconciliation_required
        ]
      ] ->
        {:ok,
         %{
           id: id,
           installed_version: installed_version,
           entitled: entitled,
           activation_state: activation_state,
           dependency_ready: dependency_ready,
           active_dependents: active_dependents,
           lifecycle_version: lifecycle_version,
           event_cursor: event_cursor,
           replay_from_cursor: replay_from_cursor,
           projection_version: projection_version,
           projection_ready: projection_ready,
           reconciliation_required: reconciliation_required
         }}

      [] ->
        {:error, :module_not_configured}
    end
  end

  defp lock_record(tenant_id, module_instance_id, record_id) do
    case Repo.query!(
           """
           SELECT id::text
           FROM synthetic_module_records
           WHERE id = $1 AND tenant_id = $2 AND module_instance_id = $3 AND retained = true
           FOR UPDATE
           """,
           [dump_uuid(record_id), dump_uuid(tenant_id), dump_uuid(module_instance_id)]
         ).rows do
      [[id]] -> {:ok, %{id: id}}
      [] -> {:error, :record_not_found}
    end
  end

  defp lock_mandatory_work_item(tenant_id, module_instance_id, work_item_id) do
    case Repo.query!(
           """
           SELECT id::text
           FROM synthetic_module_work_items
           WHERE id = $1
             AND tenant_id = $2
             AND module_instance_id = $3
             AND work_kind = 'mandatory'
             AND status IN ('queued', 'running')
           FOR UPDATE
           """,
           [dump_uuid(work_item_id), dump_uuid(tenant_id), dump_uuid(module_instance_id)]
         ).rows do
      [[id]] -> {:ok, %{id: id}}
      [] -> {:error, :mandatory_work_not_available}
    end
  end

  defp require_entitlement(%{entitled: true}), do: :ok
  defp require_entitlement(_instance), do: {:error, :module_not_entitled}

  defp require_dependency(%{dependency_ready: true}), do: :ok
  defp require_dependency(_instance), do: {:error, :required_dependency_inactive}

  defp require_state(%{activation_state: state}, state), do: :ok

  defp require_state(%{activation_state: "active"}, "inactive"),
    do: {:error, :module_already_active}

  defp require_state(_instance, "active"), do: {:error, :module_inactive}
  defp require_state(_instance, "inactive"), do: {:error, :module_not_inactive}

  defp require_no_active_dependents(%{active_dependents: 0}), do: :ok
  defp require_no_active_dependents(_instance), do: {:error, :active_dependents_present}

  defp require_version(%{lifecycle_version: expected_version}, expected_version), do: :ok
  defp require_version(_instance, _expected_version), do: {:error, :lifecycle_conflict}

  defp require_compatibility(%{installed_version: installed_version}, release) do
    if installed_version in release.compatible_from do
      :ok
    else
      {:error, :module_version_incompatible}
    end
  end

  defp run_lock_hook(opts) do
    case Keyword.get(opts, :after_lock) do
      nil -> :ok
      hook when is_function(hook, 0) -> hook.()
      _hook -> {:error, :invalid_lock_hook}
    end
  end

  defp increment_lifecycle_version(instance, tenant_id, next_version) do
    Repo.query!(
      """
      UPDATE synthetic_module_instances
      SET lifecycle_version = $1, updated_at = NOW()
      WHERE id = $2 AND tenant_id = $3
      """,
      [next_version, dump_uuid(instance.id), dump_uuid(tenant_id)]
    )
  end

  defp insert_event_pair(instance, context, event_type, lifecycle_version, payload) do
    Enum.each(["audit", "outbox"], fn channel ->
      Repo.query!(
        """
        INSERT INTO synthetic_module_lifecycle_events (
          id,
          tenant_id,
          module_instance_id,
          actor_id,
          channel,
          event_type,
          lifecycle_version,
          correlation_id,
          classification,
          payload,
          inserted_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'internal', $9::jsonb, NOW())
        """,
        [
          dump_uuid(UUID.generate()),
          dump_uuid(context.tenant_id),
          dump_uuid(instance.id),
          dump_uuid(context.actor.id),
          channel,
          event_type,
          lifecycle_version,
          dump_uuid(context.correlation_id),
          payload
        ]
      )
    end)
  end

  defp validate_release_entry!(%{key: key, version: version, compatible_from: compatible_from})
       when is_binary(key) and byte_size(key) > 0 and is_binary(version) and
              byte_size(version) > 0 and is_list(compatible_from) do
    if Enum.all?(compatible_from, &(is_binary(&1) and byte_size(&1) > 0)) do
      :ok
    else
      raise ArgumentError, "invalid release module"
    end
  end

  defp validate_release_entry!(_entry), do: raise(ArgumentError, "invalid release module")

  defp cast_uuid(value, reason) do
    case UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> {:error, reason}
    end
  end

  defp dump_uuid(uuid), do: UUID.dump!(uuid)
end
