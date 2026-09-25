defmodule Chimwemwe.Platform.ModuleLifecycle.ActivateModule do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  alias Chimwemwe.Platform.{Authority, ModuleLifecycleError, TrustedActor}

  alias Chimwemwe.Platform.ModuleLifecycle.{
    ActivateModuleResult,
    ReleaseManifest
  }

  alias Chimwemwe.Repo
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  @action_name "platform.module_lifecycle.activate"
  @aggregate_type "platform.module_activation"
  @event_type "platform.module.activated"
  @manage_capability "platform.modules.activate"
  @schema_version 1

  @impl true
  def run(input, _options, context) do
    with {:ok, action_context} <- validate_context(context, input.arguments.module_key),
         :ok <- lock_lifecycle(action_context.tenant_id, input.arguments.module_key),
         :ok <- reauthorize(action_context.actor),
         request_hash <- request_hash(action_context.declaration, input.arguments),
         {:ok, claim} <- claim(action_context, input.arguments, request_hash) do
      execute_or_replay(action_context, input.arguments, request_hash, claim)
    end
  rescue
    _error -> lifecycle_error(:retryable_dependency)
  catch
    :exit, _reason -> lifecycle_error(:retryable_dependency)
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

  defp reauthorize(actor) do
    if Authority.actor_has_capability?(actor, @manage_capability) do
      :ok
    else
      lifecycle_error(:forbidden)
    end
  end

  defp claim(context, arguments, request_hash) do
    claim_id = UUID.generate()
    activation_id = UUID.generate()

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
             @action_name,
             dump_uuid(arguments.idempotency_key),
             @aggregate_type,
             dump_uuid(activation_id),
             request_hash
           ]
         ) do
      {:ok, %{rows: [[^claim_id]]}} -> {:ok, {:new, claim_id, activation_id}}
      {:ok, %{rows: []}} -> load_claim(context.tenant_id, arguments.idempotency_key)
      {:error, error} -> translate_query_error(error)
    end
  end

  defp load_claim(tenant_id, idempotency_key) do
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
           [dump_uuid(tenant_id), @action_name, dump_uuid(idempotency_key)]
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

      {:error, error} ->
        translate_query_error(error)
    end
  end

  defp execute_or_replay(context, arguments, _request_hash, {:new, claim_id, activation_id}) do
    execute_activation(context, arguments, claim_id, activation_id)
  end

  defp execute_or_replay(context, _arguments, request_hash, {:existing, claim}) do
    if claim.status == "completed" and claim.actor_id == context.actor_id and
         claim.request_hash == request_hash do
      replay_result(claim)
    else
      lifecycle_error(:idempotency_conflict)
    end
  end

  defp replay_result(claim) do
    with %{
           "activation_id" => activation_id,
           "module_key" => module_key,
           "module_version" => module_version,
           "lock_version" => lock_version
         } <- claim.result_payload,
         {:ok, activation_id} <- cast_uuid(activation_id),
         true <- activation_id == claim.aggregate_id,
         true <- is_binary(module_key) and module_key != "",
         true <- is_binary(module_version) and module_version != "",
         true <- lock_version == 1,
         {:ok, audit_reference} <- cast_uuid(claim.audit_reference),
         {:ok, event_id} <- cast_uuid(claim.event_id) do
      {:ok,
       %ActivateModuleResult{
         id: activation_id,
         module_key: module_key,
         module_version: module_version,
         lock_version: lock_version,
         audit_reference: audit_reference,
         event_id: event_id
       }}
    else
      _invalid_stored_result -> lifecycle_error(:retryable_dependency)
    end
  end

  defp execute_activation(context, arguments, claim_id, activation_id) do
    with {:ok, entitlement_id} <- lock_entitlement(context.tenant_id, arguments.module_key),
         :ok <- require_dependencies(context),
         :ok <- insert_activation(context, entitlement_id, activation_id),
         audit_reference <- UUID.generate(),
         event_id <- UUID.generate(),
         :ok <- insert_audit(context, arguments, activation_id, audit_reference),
         :ok <- insert_outbox(context, arguments, activation_id, audit_reference, event_id),
         :ok <- complete_claim(claim_id, context, activation_id, audit_reference, event_id) do
      {:ok,
       %ActivateModuleResult{
         id: activation_id,
         module_key: context.declaration.key,
         module_version: context.declaration.version,
         lock_version: 1,
         audit_reference: audit_reference,
         event_id: event_id
       }}
    end
  end

  defp lock_entitlement(tenant_id, module_key) do
    case Repo.query(
           """
           SELECT id::text
           FROM platform_module_entitlements
           WHERE tenant_id = $1 AND module_key = $2
           FOR KEY SHARE
           """,
           [dump_uuid(tenant_id), module_key]
         ) do
      {:ok, %{rows: [[entitlement_id]]}} -> {:ok, entitlement_id}
      {:ok, %{rows: []}} -> lifecycle_error(:module_not_entitled)
      {:error, error} -> translate_query_error(error)
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
           FOR KEY SHARE OF activation, entitlement
           """,
           [dump_uuid(tenant_id), dependency.key, dependency.version]
         ) do
      {:ok, %{rows: [[1]]}} -> :ok
      {:ok, %{rows: []}} -> lifecycle_error(:required_dependency_inactive)
      {:error, error} -> translate_query_error(error)
    end
  end

  defp insert_activation(context, entitlement_id, activation_id) do
    case Repo.query(
           """
           INSERT INTO platform_module_activations (
             id,
             tenant_id,
             entitlement_id,
             module_version,
             state,
             lock_version,
             activated_at,
             inserted_at,
             updated_at
           )
           VALUES ($1, $2, $3, $4, 'active', 1, NOW(), NOW(), NOW())
           """,
           [
             dump_uuid(activation_id),
             dump_uuid(context.tenant_id),
             dump_uuid(entitlement_id),
             context.declaration.version
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, error} -> translate_query_error(error)
    end
  end

  defp insert_audit(context, arguments, activation_id, audit_reference) do
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
             $1, $2, $3, $4, $5, $6, $7, $8, $9, 0, 1,
             jsonb_build_object(
               'module_key', $10::text,
               'module_version', $11::text,
               'state', 'active'
             ),
             NOW(), NOW()
           )
           """,
           [
             dump_uuid(audit_reference),
             dump_uuid(context.tenant_id),
             dump_uuid(context.actor_id),
             @action_name,
             @aggregate_type,
             dump_uuid(activation_id),
             dump_uuid(arguments.idempotency_key),
             dump_uuid(context.correlation_id),
             dump_uuid(arguments.causation_id),
             context.declaration.key,
             context.declaration.version
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, error} -> translate_query_error(error)
    end
  end

  defp insert_outbox(context, arguments, activation_id, audit_reference, event_id) do
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
             $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'internal',
             jsonb_build_object(
               'module_key', $12::text,
               'module_version', $13::text,
               'lock_version', 1
             ),
             NOW(), NOW()
           )
           """,
           [
             dump_uuid(event_id),
             dump_uuid(context.tenant_id),
             dump_uuid(context.actor_id),
             @aggregate_type,
             dump_uuid(activation_id),
             @event_type,
             @schema_version,
             context.routing_version,
             dump_uuid(context.correlation_id),
             dump_uuid(arguments.causation_id),
             dump_uuid(audit_reference),
             context.declaration.key,
             context.declaration.version
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, error} -> translate_query_error(error)
    end
  end

  defp complete_claim(claim_id, context, activation_id, audit_reference, event_id) do
    case Repo.query(
           """
           UPDATE platform_authority_action_idempotency
           SET status = 'completed',
               result_payload = jsonb_build_object(
                 'activation_id', $2::uuid,
                 'module_key', $3::text,
                 'module_version', $4::text,
                 'lock_version', 1
               ),
               audit_reference = $5,
               event_id = $6,
               completed_at = NOW(),
               updated_at = NOW()
           WHERE id = $1 AND status = 'started'
           """,
           [
             dump_uuid(claim_id),
             dump_uuid(activation_id),
             context.declaration.key,
             context.declaration.version,
             dump_uuid(audit_reference),
             dump_uuid(event_id)
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:ok, _unexpected} -> lifecycle_error(:retryable_dependency)
      {:error, error} -> translate_query_error(error)
    end
  end

  defp request_hash(declaration, arguments) do
    {
      @action_name,
      declaration.key,
      declaration.version,
      declaration.dependencies,
      arguments.expected_version,
      arguments.causation_id
    }
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
  end

  defp translate_query_error(%PostgrexError{postgres: %{constraint: constraint}})
       when constraint in [
              "platform_module_activations_entitlement_index",
              :platform_module_activations_entitlement_index
            ],
       do: lifecycle_error(:conflict)

  defp translate_query_error(_error), do: lifecycle_error(:retryable_dependency)

  defp cast_uuid(value) do
    case UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> lifecycle_error(:invalid_input)
    end
  end

  defp dump_uuid(value), do: UUID.dump!(value)
  defp lifecycle_error(code), do: {:error, %ModuleLifecycleError{code: code}}
end
