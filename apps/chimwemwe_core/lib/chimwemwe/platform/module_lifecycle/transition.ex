defmodule Chimwemwe.Platform.ModuleLifecycle.Transition do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  alias Chimwemwe.Platform.{Authority, ModuleLifecycleError, TrustedActor}

  alias Chimwemwe.Platform.ModuleLifecycle.{
    ReleaseManifest,
    TransitionResult
  }

  alias Chimwemwe.Repo
  alias Ecto.UUID

  @aggregate_type "platform.module_activation"
  @schema_version 1

  @impl true
  def run(input, options, context) do
    with {:ok, operation} <- operation(options),
         {:ok, spec} <- operation_spec(operation),
         {:ok, action_context} <- validate_context(context, input.arguments.module_key),
         :ok <- lock_lifecycle(action_context.tenant_id, input.arguments.module_key),
         :ok <- reauthorize(action_context.actor, spec.capability),
         {:ok, activation} <-
           lock_activation(action_context.tenant_id, input.arguments.module_key),
         request_hash <- request_hash(spec, action_context.declaration, input.arguments),
         {:ok, claim} <-
           claim(action_context, activation, spec, input.arguments, request_hash) do
      execute_or_replay(
        operation,
        spec,
        action_context,
        activation,
        input.arguments,
        request_hash,
        claim
      )
    end
  rescue
    _error -> lifecycle_error(:retryable_dependency)
  catch
    :exit, _reason -> lifecycle_error(:retryable_dependency)
  end

  defp operation(options) do
    case Keyword.fetch(options, :operation) do
      {:ok, operation} when operation in [:deactivate, :complete_mandatory_work, :reactivate] ->
        {:ok, operation}

      _invalid ->
        lifecycle_error(:internal)
    end
  end

  defp operation_spec(:deactivate) do
    {:ok,
     %{
       action_name: "platform.module_lifecycle.deactivate",
       capability: "platform.modules.deactivate",
       event_type: "platform.module.deactivated",
       transition: :deactivated
     }}
  end

  defp operation_spec(:complete_mandatory_work) do
    {:ok,
     %{
       action_name: "platform.module_lifecycle.complete_mandatory_work",
       capability: "platform.modules.mandatory_work.complete",
       event_type: "platform.module.mandatory_work_completed",
       transition: :mandatory_work_completed
     }}
  end

  defp operation_spec(:reactivate) do
    {:ok,
     %{
       action_name: "platform.module_lifecycle.reactivate",
       capability: "platform.modules.reactivate",
       event_type: "platform.module.reactivated",
       transition: :reactivated
     }}
  end

  defp validate_context(
         %{
           actor: actor,
           tenant: tenant_id,
           source_context: %{
             chimwemwe: %{
               correlation_id: correlation_id,
               module_release_manifest: manifest,
               routing_version: routing_version
             }
           }
         },
         module_key
       ) do
    with {:ok, trusted_actor} <- TrustedActor.revalidate(actor),
         true <- tenant_id == TrustedActor.tenant_id(trusted_actor),
         {:ok, correlation_id} <- cast_uuid(correlation_id),
         true <- is_integer(routing_version) and routing_version > 0,
         {:ok, validated_manifest} <- ReleaseManifest.revalidate(manifest),
         {:ok, declaration} <- ReleaseManifest.fetch(validated_manifest, module_key) do
      {:ok,
       %{
         actor: trusted_actor,
         actor_id: TrustedActor.actor_id(trusted_actor),
         tenant_id: tenant_id,
         correlation_id: correlation_id,
         routing_version: routing_version,
         manifest: validated_manifest,
         declaration: declaration
       }}
    else
      {:error, :invalid_manifest} -> lifecycle_error(:invalid_manifest)
      {:error, :module_not_released} -> lifecycle_error(:module_not_released)
      _invalid -> lifecycle_error(:forbidden)
    end
  end

  defp validate_context(_context, _module_key), do: lifecycle_error(:forbidden)

  defp lock_lifecycle(tenant_id, module_key) do
    case Repo.query(
           """
           SELECT pg_advisory_xact_lock(
             hashtextextended('platform-module-lifecycle:' || $1::text || ':' || $2, 0)
           )
           """,
           [tenant_id, module_key]
         ) do
      {:ok, _result} -> :ok
      {:error, _error} -> lifecycle_error(:retryable_dependency)
    end
  end

  defp reauthorize(actor, capability) do
    if Authority.actor_has_capability?(actor, capability) do
      :ok
    else
      lifecycle_error(:forbidden)
    end
  end

  defp lock_activation(tenant_id, module_key) do
    case Repo.query(
           """
           SELECT
             activation.id::text,
             activation.entitlement_id::text,
             activation.module_version,
             activation.state,
             activation.lock_version,
             activation.consumer_cursor,
             activation.replay_from_cursor,
             activation.last_reconciled_cursor,
             activation.projection_version,
             activation.projection_ready,
             activation.reconciliation_required,
             activation.retained_data_state
           FROM platform_module_activations AS activation
           JOIN platform_module_entitlements AS entitlement
             ON entitlement.tenant_id = activation.tenant_id
            AND entitlement.id = activation.entitlement_id
           WHERE activation.tenant_id = $1
             AND entitlement.module_key = $2
           FOR UPDATE OF activation
           """,
           [dump_uuid(tenant_id), module_key]
         ) do
      {:ok,
       %{
         rows: [
           [
             id,
             entitlement_id,
             module_version,
             state,
             lock_version,
             consumer_cursor,
             replay_from_cursor,
             last_reconciled_cursor,
             projection_version,
             projection_ready,
             reconciliation_required,
             retained_data_state
           ]
         ]
       }} ->
        {:ok,
         %{
           id: id,
           entitlement_id: entitlement_id,
           module_version: module_version,
           state: state,
           lock_version: lock_version,
           consumer_cursor: consumer_cursor,
           replay_from_cursor: replay_from_cursor,
           last_reconciled_cursor: last_reconciled_cursor,
           projection_version: projection_version,
           projection_ready: projection_ready,
           reconciliation_required: reconciliation_required,
           retained_data_state: retained_data_state
         }}

      {:ok, %{rows: []}} ->
        lifecycle_error(:module_inactive)

      {:error, _error} ->
        lifecycle_error(:retryable_dependency)
    end
  end

  defp claim(context, activation, spec, arguments, request_hash) do
    claim_id = UUID.generate()

    case Repo.query(
           """
           INSERT INTO platform_authority_action_idempotency (
             id,
             tenant_id,
             actor_id,
             action_name,
             idempotency_key,
             aggregate_type,
             aggregate_id,
             request_hash,
             status,
             inserted_at,
             updated_at
           )
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'started', NOW(), NOW())
           ON CONFLICT (tenant_id, action_name, idempotency_key) DO NOTHING
           RETURNING id::text
           """,
           [
             dump_uuid(claim_id),
             dump_uuid(context.tenant_id),
             dump_uuid(context.actor_id),
             spec.action_name,
             dump_uuid(arguments.idempotency_key),
             @aggregate_type,
             dump_uuid(activation.id),
             request_hash
           ]
         ) do
      {:ok, %{rows: [[^claim_id]]}} -> {:ok, {:new, claim_id}}
      {:ok, %{rows: []}} -> load_claim(context.tenant_id, spec, arguments.idempotency_key)
      {:error, _error} -> lifecycle_error(:retryable_dependency)
    end
  end

  defp load_claim(tenant_id, spec, idempotency_key) do
    case Repo.query(
           """
           SELECT
             actor_id::text,
             aggregate_id::text,
             request_hash,
             status,
             result_payload,
             audit_reference::text,
             event_id::text
           FROM platform_authority_action_idempotency
           WHERE tenant_id = $1 AND action_name = $2 AND idempotency_key = $3
           FOR UPDATE
           """,
           [dump_uuid(tenant_id), spec.action_name, dump_uuid(idempotency_key)]
         ) do
      {:ok,
       %{
         rows: [
           [
             actor_id,
             aggregate_id,
             request_hash,
             status,
             result_payload,
             audit_reference,
             event_id
           ]
         ]
       }} ->
        {:ok,
         {:existing,
          %{
            actor_id: actor_id,
            aggregate_id: aggregate_id,
            request_hash: request_hash,
            status: status,
            result_payload: result_payload,
            audit_reference: audit_reference,
            event_id: event_id
          }}}

      {:ok, %{rows: []}} ->
        lifecycle_error(:retryable_dependency)

      {:error, _error} ->
        lifecycle_error(:retryable_dependency)
    end
  end

  defp execute_or_replay(
         _operation,
         _spec,
         context,
         activation,
         _arguments,
         request_hash,
         {:existing, claim}
       ) do
    if claim.status == "completed" and claim.actor_id == context.actor_id and
         claim.aggregate_id == activation.id and claim.request_hash == request_hash do
      replay_result(claim)
    else
      lifecycle_error(:idempotency_conflict)
    end
  end

  defp execute_or_replay(
         :deactivate,
         spec,
         context,
         activation,
         arguments,
         _request_hash,
         {:new, claim_id}
       ) do
    execute_deactivation(spec, context, activation, arguments, claim_id)
  end

  defp execute_or_replay(
         :complete_mandatory_work,
         spec,
         context,
         activation,
         arguments,
         _request_hash,
         {:new, claim_id}
       ) do
    execute_mandatory_work(spec, context, activation, arguments, claim_id)
  end

  defp execute_or_replay(
         :reactivate,
         spec,
         context,
         activation,
         arguments,
         _request_hash,
         {:new, claim_id}
       ) do
    execute_reactivation(spec, context, activation, arguments, claim_id)
  end

  defp execute_deactivation(spec, context, activation, arguments, claim_id) do
    with :ok <- require_state(activation, "active"),
         :ok <- require_version(activation, arguments.expected_version),
         :ok <- require_no_active_dependents(context, arguments.module_key),
         {:ok, parked_work_count} <- park_ordinary_work(context, activation),
         {:ok, next_version} <- mark_inactive(context, activation),
         result <-
           transition_result(
             spec,
             context,
             activation,
             module_version: activation.module_version,
             state: :inactive,
             lock_version: next_version,
             parked_work_count: parked_work_count,
             replay_from_cursor: activation.consumer_cursor,
             projection_version: activation.projection_version
           ),
         :ok <- record_transition(spec, context, activation, arguments, claim_id, result) do
      {:ok, result}
    end
  end

  defp execute_mandatory_work(spec, context, activation, arguments, claim_id) do
    with :ok <- require_version(activation, arguments.expected_version),
         {:ok, work_item} <-
           lock_mandatory_work(context.tenant_id, activation.id, arguments.work_item_id),
         :ok <- complete_work(context.tenant_id, activation.id, work_item.id),
         {:ok, next_version} <- increment_version(context, activation),
         result <-
           transition_result(
             spec,
             context,
             activation,
             module_version: activation.module_version,
             state: state_atom(activation.state),
             lock_version: next_version,
             work_item_id: work_item.id,
             replay_from_cursor: activation.replay_from_cursor,
             projection_version: activation.projection_version
           ),
         :ok <- record_transition(spec, context, activation, arguments, claim_id, result) do
      {:ok, result}
    end
  end

  defp execute_reactivation(spec, context, activation, arguments, claim_id) do
    with :ok <- require_state(activation, "inactive"),
         :ok <- require_version(activation, arguments.expected_version),
         :ok <- require_compatibility(activation, context.declaration),
         :ok <- require_dependencies(context),
         {:ok, requeued_work_count} <- requeue_ordinary_work(context, activation),
         {:ok, next_version, projection_version} <- mark_active(context, activation),
         result <-
           transition_result(
             spec,
             context,
             activation,
             module_version: context.declaration.version,
             state: :active,
             lock_version: next_version,
             requeued_work_count: requeued_work_count,
             replay_from_cursor: activation.replay_from_cursor,
             projection_version: projection_version
           ),
         :ok <- record_transition(spec, context, activation, arguments, claim_id, result) do
      {:ok, result}
    end
  end

  defp require_state(%{state: state}, state), do: :ok
  defp require_state(_activation, "active"), do: lifecycle_error(:module_inactive)
  defp require_state(_activation, "inactive"), do: lifecycle_error(:module_not_inactive)

  defp require_version(%{lock_version: version}, version), do: :ok
  defp require_version(_activation, _expected_version), do: lifecycle_error(:lifecycle_conflict)

  defp require_compatibility(activation, declaration) do
    if activation.module_version in declaration.compatible_from do
      :ok
    else
      lifecycle_error(:module_version_incompatible)
    end
  end

  defp require_no_active_dependents(context, module_key) do
    dependent_keys = ReleaseManifest.dependents(context.manifest, module_key)

    if dependent_keys == [] do
      :ok
    else
      case Repo.query(
             """
             SELECT 1
             FROM platform_module_activations AS activation
             JOIN platform_module_entitlements AS entitlement
               ON entitlement.tenant_id = activation.tenant_id
              AND entitlement.id = activation.entitlement_id
             WHERE activation.tenant_id = $1
               AND entitlement.module_key = ANY($2::text[])
               AND activation.state = 'active'
             LIMIT 1
             """,
             [dump_uuid(context.tenant_id), dependent_keys]
           ) do
        {:ok, %{rows: []}} -> :ok
        {:ok, %{rows: [[1]]}} -> lifecycle_error(:active_dependents_present)
        {:error, _error} -> lifecycle_error(:retryable_dependency)
      end
    end
  end

  defp require_dependencies(context) do
    Enum.reduce_while(context.declaration.dependencies, :ok, fn dependency_key, :ok ->
      with {:ok, dependency} <- ReleaseManifest.fetch(context.manifest, dependency_key),
           :ok <- require_active_dependency(context.tenant_id, dependency) do
        {:cont, :ok}
      else
        {:error, %ModuleLifecycleError{code: :retryable_dependency}} = error ->
          {:halt, error}

        _missing_or_inactive ->
          {:halt, lifecycle_error(:required_dependency_inactive)}
      end
    end)
  end

  defp require_active_dependency(tenant_id, dependency) do
    case Repo.query(
           """
           SELECT 1
           FROM platform_module_activations AS activation
           JOIN platform_module_entitlements AS entitlement
             ON entitlement.tenant_id = activation.tenant_id
            AND entitlement.id = activation.entitlement_id
           WHERE activation.tenant_id = $1
             AND entitlement.module_key = $2
             AND activation.state = 'active'
             AND activation.module_version = $3
           FOR KEY SHARE OF activation
           """,
           [dump_uuid(tenant_id), dependency.key, dependency.version]
         ) do
      {:ok, %{rows: [[1]]}} -> :ok
      {:ok, %{rows: []}} -> lifecycle_error(:required_dependency_inactive)
      {:error, _error} -> lifecycle_error(:retryable_dependency)
    end
  end

  defp park_ordinary_work(context, activation) do
    case Repo.query(
           """
           UPDATE platform_module_work_items
           SET status = 'parked',
               replay_cursor = COALESCE(replay_cursor, $3),
               updated_at = NOW()
           WHERE tenant_id = $1
             AND activation_id = $2
             AND work_kind = 'ordinary'
             AND status IN ('queued', 'running')
           """,
           [
             dump_uuid(context.tenant_id),
             dump_uuid(activation.id),
             activation.consumer_cursor
           ]
         ) do
      {:ok, %{num_rows: count}} -> {:ok, count}
      {:error, _error} -> lifecycle_error(:retryable_dependency)
    end
  end

  defp mark_inactive(context, activation) do
    next_version = activation.lock_version + 1

    case Repo.query(
           """
           UPDATE platform_module_activations
           SET state = 'inactive',
               lock_version = $3,
               replay_from_cursor = consumer_cursor,
               projection_ready = false,
               reconciliation_required = true,
               deactivated_at = NOW(),
               updated_at = NOW()
           WHERE id = $1 AND tenant_id = $2 AND state = 'active' AND lock_version = $4
           """,
           [
             dump_uuid(activation.id),
             dump_uuid(context.tenant_id),
             next_version,
             activation.lock_version
           ]
         ) do
      {:ok, %{num_rows: 1}} -> {:ok, next_version}
      {:ok, _unexpected} -> lifecycle_error(:lifecycle_conflict)
      {:error, _error} -> lifecycle_error(:retryable_dependency)
    end
  end

  defp lock_mandatory_work(tenant_id, activation_id, work_item_id) do
    case Repo.query(
           """
           SELECT id::text, work_kind
           FROM platform_module_work_items
           WHERE id = $1
             AND tenant_id = $2
             AND activation_id = $3
             AND work_kind <> 'ordinary'
             AND status IN ('queued', 'running')
           FOR UPDATE
           """,
           [dump_uuid(work_item_id), dump_uuid(tenant_id), dump_uuid(activation_id)]
         ) do
      {:ok, %{rows: [[id, work_kind]]}} -> {:ok, %{id: id, work_kind: work_kind}}
      {:ok, %{rows: []}} -> lifecycle_error(:mandatory_work_not_available)
      {:error, _error} -> lifecycle_error(:retryable_dependency)
    end
  end

  defp complete_work(tenant_id, activation_id, work_item_id) do
    case Repo.query(
           """
           UPDATE platform_module_work_items
           SET status = 'completed', updated_at = NOW()
           WHERE id = $1 AND tenant_id = $2 AND activation_id = $3
           """,
           [dump_uuid(work_item_id), dump_uuid(tenant_id), dump_uuid(activation_id)]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:ok, _unexpected} -> lifecycle_error(:mandatory_work_not_available)
      {:error, _error} -> lifecycle_error(:retryable_dependency)
    end
  end

  defp increment_version(context, activation) do
    next_version = activation.lock_version + 1

    case Repo.query(
           """
           UPDATE platform_module_activations
           SET lock_version = $3, updated_at = NOW()
           WHERE id = $1 AND tenant_id = $2 AND lock_version = $4
           """,
           [
             dump_uuid(activation.id),
             dump_uuid(context.tenant_id),
             next_version,
             activation.lock_version
           ]
         ) do
      {:ok, %{num_rows: 1}} -> {:ok, next_version}
      {:ok, _unexpected} -> lifecycle_error(:lifecycle_conflict)
      {:error, _error} -> lifecycle_error(:retryable_dependency)
    end
  end

  defp requeue_ordinary_work(context, activation) do
    case Repo.query(
           """
           UPDATE platform_module_work_items
           SET status = 'queued',
               replay_cursor = COALESCE(replay_cursor, $3),
               updated_at = NOW()
           WHERE tenant_id = $1
             AND activation_id = $2
             AND work_kind = 'ordinary'
             AND status = 'parked'
           """,
           [
             dump_uuid(context.tenant_id),
             dump_uuid(activation.id),
             activation.replay_from_cursor
           ]
         ) do
      {:ok, %{num_rows: count}} -> {:ok, count}
      {:error, _error} -> lifecycle_error(:retryable_dependency)
    end
  end

  defp mark_active(context, activation) do
    next_version = activation.lock_version + 1
    projection_version = activation.projection_version + 1

    case Repo.query(
           """
           UPDATE platform_module_activations
           SET state = 'active',
               module_version = $3,
               lock_version = $4,
               last_reconciled_cursor = replay_from_cursor,
               replay_from_cursor = NULL,
               projection_version = $5,
               projection_ready = true,
               reconciliation_required = false,
               reactivated_at = NOW(),
               updated_at = NOW()
           WHERE id = $1 AND tenant_id = $2 AND state = 'inactive' AND lock_version = $6
           """,
           [
             dump_uuid(activation.id),
             dump_uuid(context.tenant_id),
             context.declaration.version,
             next_version,
             projection_version,
             activation.lock_version
           ]
         ) do
      {:ok, %{num_rows: 1}} -> {:ok, next_version, projection_version}
      {:ok, _unexpected} -> lifecycle_error(:lifecycle_conflict)
      {:error, _error} -> lifecycle_error(:retryable_dependency)
    end
  end

  defp transition_result(spec, context, activation, attrs) do
    struct!(TransitionResult,
      id: activation.id,
      transition: spec.transition,
      module_key: context.declaration.key,
      module_version: Keyword.fetch!(attrs, :module_version),
      state: Keyword.fetch!(attrs, :state),
      lock_version: Keyword.fetch!(attrs, :lock_version),
      audit_reference: UUID.generate(),
      event_id: UUID.generate(),
      work_item_id: Keyword.get(attrs, :work_item_id),
      parked_work_count: Keyword.get(attrs, :parked_work_count),
      requeued_work_count: Keyword.get(attrs, :requeued_work_count),
      replay_from_cursor: Keyword.get(attrs, :replay_from_cursor),
      projection_version: Keyword.fetch!(attrs, :projection_version)
    )
  end

  defp record_transition(spec, context, activation, arguments, claim_id, result) do
    with :ok <- insert_audit(spec, context, activation, arguments, result),
         :ok <- insert_outbox(spec, context, arguments, result) do
      complete_claim(claim_id, result)
    end
  end

  defp insert_audit(spec, context, activation, arguments, result) do
    case Repo.query(
           """
           INSERT INTO platform_authority_audit_events (
             id,
             tenant_id,
             actor_id,
             action_name,
             aggregate_type,
             aggregate_id,
             idempotency_key,
             correlation_id,
             causation_id,
             before_version,
             after_version,
             change_summary,
             occurred_at,
             inserted_at
           )
           VALUES (
             $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12::jsonb,
             NOW(), NOW()
           )
           """,
           [
             dump_uuid(result.audit_reference),
             dump_uuid(context.tenant_id),
             dump_uuid(context.actor_id),
             spec.action_name,
             @aggregate_type,
             dump_uuid(result.id),
             dump_uuid(arguments.idempotency_key),
             dump_uuid(context.correlation_id),
             dump_uuid(arguments.causation_id),
             activation.lock_version,
             result.lock_version,
             result_payload(result)
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, _error} -> lifecycle_error(:retryable_dependency)
    end
  end

  defp insert_outbox(spec, context, arguments, result) do
    case Repo.query(
           """
           INSERT INTO platform_outbox_events (
             id,
             tenant_id,
             actor_id,
             aggregate_type,
             aggregate_id,
             event_type,
             schema_version,
             routing_version,
             correlation_id,
             causation_id,
             audit_reference,
             classification,
             payload,
             occurred_at,
             inserted_at
           )
           VALUES (
             $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'internal', $12::jsonb,
             NOW(), NOW()
           )
           """,
           [
             dump_uuid(result.event_id),
             dump_uuid(context.tenant_id),
             dump_uuid(context.actor_id),
             @aggregate_type,
             dump_uuid(result.id),
             spec.event_type,
             @schema_version,
             context.routing_version,
             dump_uuid(context.correlation_id),
             dump_uuid(arguments.causation_id),
             dump_uuid(result.audit_reference),
             result_payload(result)
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, _error} -> lifecycle_error(:retryable_dependency)
    end
  end

  defp complete_claim(claim_id, result) do
    case Repo.query(
           """
           UPDATE platform_authority_action_idempotency
           SET status = 'completed',
               result_payload = $2::jsonb,
               audit_reference = $3,
               event_id = $4,
               completed_at = NOW(),
               updated_at = NOW()
           WHERE id = $1 AND status = 'started'
           """,
           [
             dump_uuid(claim_id),
             result_payload(result),
             dump_uuid(result.audit_reference),
             dump_uuid(result.event_id)
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:ok, _unexpected} -> lifecycle_error(:retryable_dependency)
      {:error, _error} -> lifecycle_error(:retryable_dependency)
    end
  end

  defp result_payload(result) do
    %{
      "activation_id" => result.id,
      "transition" => Atom.to_string(result.transition),
      "module_key" => result.module_key,
      "module_version" => result.module_version,
      "state" => Atom.to_string(result.state),
      "lock_version" => result.lock_version,
      "work_item_id" => result.work_item_id,
      "parked_work_count" => result.parked_work_count,
      "requeued_work_count" => result.requeued_work_count,
      "replay_from_cursor" => result.replay_from_cursor,
      "projection_version" => result.projection_version
    }
  end

  defp replay_result(claim) do
    with payload when is_map(payload) <- claim.result_payload,
         {:ok, activation_id} <- cast_uuid(payload["activation_id"]),
         true <- activation_id == claim.aggregate_id,
         {:ok, transition} <- cast_transition(payload["transition"]),
         module_key when is_binary(module_key) and module_key != "" <- payload["module_key"],
         module_version when is_binary(module_version) and module_version != "" <-
           payload["module_version"],
         {:ok, state} <- cast_state(payload["state"]),
         lock_version when is_integer(lock_version) and lock_version > 0 <-
           payload["lock_version"],
         {:ok, work_item_id} <- cast_optional_uuid(payload["work_item_id"]),
         {:ok, parked_work_count} <- optional_nonnegative(payload["parked_work_count"]),
         {:ok, requeued_work_count} <- optional_nonnegative(payload["requeued_work_count"]),
         {:ok, replay_from_cursor} <- optional_nonnegative(payload["replay_from_cursor"]),
         projection_version when is_integer(projection_version) and projection_version > 0 <-
           payload["projection_version"],
         {:ok, audit_reference} <- cast_uuid(claim.audit_reference),
         {:ok, event_id} <- cast_uuid(claim.event_id) do
      {:ok,
       %TransitionResult{
         id: activation_id,
         transition: transition,
         module_key: module_key,
         module_version: module_version,
         state: state,
         lock_version: lock_version,
         audit_reference: audit_reference,
         event_id: event_id,
         work_item_id: work_item_id,
         parked_work_count: parked_work_count,
         requeued_work_count: requeued_work_count,
         replay_from_cursor: replay_from_cursor,
         projection_version: projection_version
       }}
    else
      _invalid -> lifecycle_error(:retryable_dependency)
    end
  end

  defp request_hash(spec, declaration, arguments) do
    {
      spec.action_name,
      declaration.key,
      declaration.version,
      declaration.dependencies,
      declaration.compatible_from,
      arguments.expected_version,
      Map.get(arguments, :work_item_id),
      arguments.causation_id
    }
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
  end

  defp cast_transition("deactivated"), do: {:ok, :deactivated}
  defp cast_transition("mandatory_work_completed"), do: {:ok, :mandatory_work_completed}
  defp cast_transition("reactivated"), do: {:ok, :reactivated}
  defp cast_transition(_transition), do: lifecycle_error(:retryable_dependency)

  defp cast_state("active"), do: {:ok, :active}
  defp cast_state("inactive"), do: {:ok, :inactive}
  defp cast_state(_state), do: lifecycle_error(:retryable_dependency)

  defp state_atom("active"), do: :active
  defp state_atom("inactive"), do: :inactive

  defp cast_optional_uuid(nil), do: {:ok, nil}
  defp cast_optional_uuid(value), do: cast_uuid(value)

  defp optional_nonnegative(nil), do: {:ok, nil}
  defp optional_nonnegative(value) when is_integer(value) and value >= 0, do: {:ok, value}
  defp optional_nonnegative(_value), do: lifecycle_error(:retryable_dependency)

  defp cast_uuid(value) do
    case UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> lifecycle_error(:invalid_input)
    end
  end

  defp dump_uuid(value), do: UUID.dump!(value)
  defp lifecycle_error(code), do: {:error, %ModuleLifecycleError{code: code}}
end
