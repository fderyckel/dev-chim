defmodule Chimwemwe.Platform.GovernedExtension.PublishDefinition do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  alias Chimwemwe.Platform.{
    ExecutionContext,
    GovernedExtensionError,
    ModuleLifecycle,
    ModuleLifecycleError,
    TrustedActor
  }

  alias Chimwemwe.Platform.GovernedExtension.{PublishResult, Registry}
  alias Chimwemwe.Platform.ModuleLifecycle.ReleaseManifest
  alias Chimwemwe.Repo
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  @action_name "platform.extensions.definition.publish"
  @aggregate_type "platform.governed_extension.definition"
  @event_type "platform.extensions.definition.published"
  @publish_capability "platform.extensions.definitions.publish"
  @event_schema_version 1

  @impl true
  def run(input, _options, context) do
    with {:ok, action_context} <- validate_context(context),
         {:ok, declaration} <- load_contract(action_context, input.arguments),
         {:ok, content, classification} <-
           validate_definition(declaration, input.arguments),
         true <- Repo.in_transaction?(),
         :ok <- authorize_module(action_context, declaration),
         {:ok, activation} <- load_activation(action_context, declaration),
         :ok <- lock_definition(action_context, activation.id, input.arguments.definition_key),
         request_hash <- request_hash(input.arguments, content),
         {:ok, claim} <- claim(action_context, input.arguments, request_hash) do
      execute_or_replay(
        action_context,
        declaration,
        activation,
        input.arguments,
        content,
        classification,
        request_hash,
        claim
      )
    else
      false -> extension_error(:retryable_dependency)
      {:error, %GovernedExtensionError{}} = error -> error
    end
  rescue
    _error -> extension_error(:retryable_dependency)
  catch
    :exit, _reason -> extension_error(:retryable_dependency)
  end

  defp validate_context(%{
         actor: actor,
         tenant: tenant_id,
         source_context: %{
           chimwemwe: %{
             correlation_id: correlation_id,
             governed_extension: %{
               execution_context: execution_context,
               manifest: manifest,
               registry: registry
             },
             routing_version: routing_version
           }
         }
       }) do
    with :ok <- ExecutionContext.validate(execution_context),
         {:ok, trusted_actor} <- TrustedActor.revalidate(actor),
         true <- execution_context.actor == trusted_actor,
         true <- tenant_id == TrustedActor.tenant_id(trusted_actor),
         {:ok, manifest} <- ReleaseManifest.revalidate(manifest),
         {:ok, registry} <- Registry.revalidate(registry),
         {:ok, correlation_id} <- cast_uuid(correlation_id),
         true <- is_integer(routing_version) and routing_version > 0 do
      {:ok,
       %{
         actor: trusted_actor,
         actor_id: TrustedActor.actor_id(trusted_actor),
         correlation_id: correlation_id,
         execution_context: execution_context,
         manifest: manifest,
         registry: registry,
         routing_version: routing_version,
         tenant_id: tenant_id
       }}
    else
      _invalid -> extension_error(:forbidden)
    end
  end

  defp validate_context(_context), do: extension_error(:forbidden)

  defp load_contract(context, arguments) do
    with {:ok, declaration} <- Registry.fetch(context.registry, arguments.schema_key),
         {:ok, released} <-
           ReleaseManifest.fetch_extension(
             context.manifest,
             declaration.module_key,
             declaration.schema_key
           ),
         true <- released.schema_version == declaration.schema_version do
      {:ok, declaration}
    else
      _missing_or_incompatible -> extension_error(:schema_not_available)
    end
  end

  defp validate_definition(declaration, arguments) do
    with true <- declaration.descriptor["revision"] == arguments.descriptor_revision,
         {:ok, content, classification} <-
           Registry.validate_content(declaration, arguments.content) do
      {:ok, content, classification}
    else
      false -> extension_error(:stale_descriptor)
      {:error, :invalid_definition} -> extension_error(:invalid_definition)
      {:error, :reference_not_allowed} -> extension_error(:reference_not_allowed)
    end
  end

  defp authorize_module(context, declaration) do
    case ModuleLifecycle.authorize_current_transaction(
           context.manifest,
           context.execution_context,
           declaration.module_key,
           @publish_capability
         ) do
      :ok ->
        :ok

      {:error, %ModuleLifecycleError{code: :forbidden}} ->
        extension_error(:forbidden)

      {:error, %ModuleLifecycleError{code: :retryable_dependency}} ->
        extension_error(:retryable_dependency)

      {:error, %ModuleLifecycleError{}} ->
        extension_error(:module_gate_failed)
    end
  end

  defp load_activation(context, declaration) do
    case Repo.query(
           """
           SELECT activation.id::text, activation.module_version
           FROM platform_module_activations AS activation
           JOIN platform_module_entitlements AS entitlement
             ON entitlement.tenant_id = activation.tenant_id
            AND entitlement.id = activation.entitlement_id
           WHERE activation.tenant_id = $1
             AND entitlement.module_key = $2
             AND activation.state = 'active'
           """,
           [dump_uuid(context.tenant_id), declaration.module_key]
         ) do
      {:ok, %{rows: [[id, version]]}} -> {:ok, %{id: id, version: version}}
      {:ok, %{rows: []}} -> extension_error(:module_gate_failed)
      {:error, _error} -> extension_error(:retryable_dependency)
    end
  end

  defp lock_definition(context, activation_id, definition_key) do
    case Repo.query(
           """
           SELECT pg_advisory_xact_lock(
             hashtextextended(
               'platform-governed-extension:' || $1::text || ':' || $2::text || ':' || $3,
               0
             )
           )
           """,
           [context.tenant_id, activation_id, definition_key]
         ) do
      {:ok, _result} -> :ok
      {:error, _error} -> extension_error(:retryable_dependency)
    end
  end

  defp claim(context, arguments, request_hash) do
    claim_id = UUID.generate()

    case Repo.query(
           """
           INSERT INTO platform_authority_action_idempotency (
             id, tenant_id, actor_id, action_name, idempotency_key,
             aggregate_type, aggregate_id, request_hash, status, inserted_at, updated_at
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
             dump_uuid(arguments.definition_id),
             request_hash
           ]
         ) do
      {:ok, %{rows: [[^claim_id]]}} -> {:ok, {:new, claim_id}}
      {:ok, %{rows: []}} -> load_claim(context.tenant_id, arguments.idempotency_key)
      {:error, error} -> translate_query_error(error)
    end
  end

  defp load_claim(tenant_id, idempotency_key) do
    case Repo.query(
           """
           SELECT actor_id::text, aggregate_id::text, request_hash, status,
                  result_payload, audit_reference::text, event_id::text
           FROM platform_authority_action_idempotency
           WHERE tenant_id = $1 AND action_name = $2 AND idempotency_key = $3
           FOR UPDATE
           """,
           [dump_uuid(tenant_id), @action_name, dump_uuid(idempotency_key)]
         ) do
      {:ok, %{rows: [[actor_id, aggregate_id, request_hash, status, payload, audit, event]]}} ->
        {:ok,
         {:existing,
          %{
            actor_id: actor_id,
            aggregate_id: aggregate_id,
            audit_reference: audit,
            event_id: event,
            request_hash: request_hash,
            result_payload: payload,
            status: status
          }}}

      {:ok, %{rows: []}} ->
        extension_error(:retryable_dependency)

      {:error, error} ->
        translate_query_error(error)
    end
  end

  defp execute_or_replay(
         context,
         declaration,
         activation,
         arguments,
         content,
         classification,
         _request_hash,
         {:new, claim_id}
       ) do
    publish(
      context,
      declaration,
      activation,
      arguments,
      content,
      classification,
      claim_id
    )
  end

  defp execute_or_replay(
         context,
         _declaration,
         _activation,
         arguments,
         _content,
         _classification,
         request_hash,
         {:existing, claim}
       ) do
    if claim.status == "completed" and claim.actor_id == context.actor_id and
         claim.aggregate_id == arguments.definition_id and claim.request_hash == request_hash do
      decode_result(claim)
    else
      extension_error(:idempotency_conflict)
    end
  end

  defp publish(context, declaration, activation, arguments, content, classification, claim_id) do
    with {:ok, current} <- load_current(context.tenant_id, arguments.definition_id),
         {:ok, next_version} <- require_expected_state(current, activation.id, arguments),
         :ok <-
           persist_definition(
             context,
             declaration,
             activation,
             arguments,
             content,
             classification,
             current,
             next_version
           ),
         result <- build_result(arguments, classification, next_version),
         :ok <- insert_audit(context, declaration, arguments, result),
         :ok <- insert_outbox(context, declaration, arguments, result),
         :ok <- complete_claim(claim_id, result) do
      {:ok, result}
    end
  end

  defp load_current(tenant_id, definition_id) do
    case Repo.query(
           """
           SELECT module_activation_id::text, definition_key, schema_key, lock_version
           FROM platform_governed_extension_definitions
           WHERE tenant_id = $1 AND id = $2
           FOR UPDATE
           """,
           [dump_uuid(tenant_id), dump_uuid(definition_id)]
         ) do
      {:ok, %{rows: [[activation_id, definition_key, schema_key, lock_version]]}} ->
        {:ok,
         %{
           activation_id: activation_id,
           definition_key: definition_key,
           lock_version: lock_version,
           schema_key: schema_key
         }}

      {:ok, %{rows: []}} ->
        {:ok, nil}

      {:error, error} ->
        translate_query_error(error)
    end
  end

  defp require_expected_state(nil, _activation_id, %{expected_version: 0}), do: {:ok, 1}

  defp require_expected_state(nil, _activation_id, _arguments), do: extension_error(:not_found)

  defp require_expected_state(current, activation_id, arguments) do
    cond do
      current.activation_id != activation_id -> extension_error(:not_found)
      current.definition_key != arguments.definition_key -> extension_error(:not_found)
      current.schema_key != arguments.schema_key -> extension_error(:not_found)
      arguments.expected_version == 0 -> extension_error(:conflict)
      current.lock_version != arguments.expected_version -> extension_error(:conflict)
      true -> {:ok, current.lock_version + 1}
    end
  end

  defp persist_definition(
         context,
         declaration,
         activation,
         arguments,
         content,
         classification,
         nil,
         1
       ) do
    case Repo.query(
           """
           INSERT INTO platform_governed_extension_definitions (
             id, tenant_id, module_activation_id, definition_key, schema_key, schema_version,
             module_version, resource_ref, descriptor_revision, classification, content,
             lock_version, created_by, updated_by, inserted_at, updated_at
           )
           VALUES (
             $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::jsonb,
             1, $12, $12, NOW(), NOW()
           )
           """,
           definition_params(
             context,
             declaration,
             activation,
             arguments,
             content,
             classification
           )
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, error} -> translate_query_error(error)
    end
  end

  defp persist_definition(
         context,
         declaration,
         activation,
         arguments,
         content,
         classification,
         _current,
         next_version
       ) do
    params =
      definition_params(context, declaration, activation, arguments, content, classification) ++
        [arguments.expected_version]

    case Repo.query(
           """
           UPDATE platform_governed_extension_definitions
           SET schema_version = $6,
               module_version = $7,
               resource_ref = $8,
               descriptor_revision = $9,
               classification = $10,
               content = $11::jsonb,
               lock_version = lock_version + 1,
               updated_by = $12,
               updated_at = NOW()
           WHERE id = $1 AND tenant_id = $2 AND module_activation_id = $3
             AND definition_key = $4 AND schema_key = $5 AND lock_version = $13
           """,
           params
         ) do
      {:ok, %{num_rows: 1}} when next_version == arguments.expected_version + 1 -> :ok
      {:ok, _unexpected} -> extension_error(:conflict)
      {:error, error} -> translate_query_error(error)
    end
  end

  defp definition_params(context, declaration, activation, arguments, content, classification) do
    [
      dump_uuid(arguments.definition_id),
      dump_uuid(context.tenant_id),
      dump_uuid(activation.id),
      arguments.definition_key,
      arguments.schema_key,
      declaration.schema_version,
      activation.version,
      declaration.descriptor["resource_ref"],
      arguments.descriptor_revision,
      Atom.to_string(classification),
      content,
      dump_uuid(context.actor_id)
    ]
  end

  defp build_result(arguments, classification, lock_version) do
    %PublishResult{
      audit_reference: UUID.generate(),
      classification: classification,
      definition_key: arguments.definition_key,
      descriptor_revision: arguments.descriptor_revision,
      event_id: UUID.generate(),
      id: arguments.definition_id,
      lock_version: lock_version,
      schema_key: arguments.schema_key
    }
  end

  defp insert_audit(context, declaration, arguments, result) do
    case Repo.query(
           """
           INSERT INTO platform_authority_audit_events (
             id, tenant_id, actor_id, action_name, aggregate_type, aggregate_id,
             idempotency_key, correlation_id, causation_id, before_version, after_version,
             change_summary, occurred_at, inserted_at
           )
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12::jsonb, NOW(), NOW())
           """,
           [
             dump_uuid(result.audit_reference),
             dump_uuid(context.tenant_id),
             dump_uuid(context.actor_id),
             @action_name,
             @aggregate_type,
             dump_uuid(result.id),
             dump_uuid(arguments.idempotency_key),
             dump_uuid(context.correlation_id),
             dump_uuid(arguments.causation_id),
             result.lock_version - 1,
             result.lock_version,
             evidence_payload(declaration, result)
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, error} -> translate_query_error(error)
    end
  end

  defp insert_outbox(context, declaration, arguments, result) do
    case Repo.query(
           """
           INSERT INTO platform_outbox_events (
             id, tenant_id, actor_id, aggregate_type, aggregate_id, event_type,
             schema_version, routing_version, correlation_id, causation_id, audit_reference,
             classification, payload, occurred_at, inserted_at
           )
           VALUES (
             $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11,
             'internal', $12::jsonb, NOW(), NOW()
           )
           """,
           [
             dump_uuid(result.event_id),
             dump_uuid(context.tenant_id),
             dump_uuid(context.actor_id),
             @aggregate_type,
             dump_uuid(result.id),
             @event_type,
             @event_schema_version,
             context.routing_version,
             dump_uuid(context.correlation_id),
             dump_uuid(arguments.causation_id),
             dump_uuid(result.audit_reference),
             evidence_payload(declaration, result)
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, error} -> translate_query_error(error)
    end
  end

  defp complete_claim(claim_id, result) do
    case Repo.query(
           """
           UPDATE platform_authority_action_idempotency
           SET status = 'completed', result_payload = $2::jsonb,
               audit_reference = $3, event_id = $4, completed_at = NOW(), updated_at = NOW()
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
      {:ok, _unexpected} -> extension_error(:retryable_dependency)
      {:error, error} -> translate_query_error(error)
    end
  end

  defp evidence_payload(declaration, result) do
    %{
      "classification" => Atom.to_string(result.classification),
      "descriptor_revision" => result.descriptor_revision,
      "lock_version" => result.lock_version,
      "module_key" => declaration.module_key,
      "schema_key" => result.schema_key,
      "schema_version" => declaration.schema_version
    }
  end

  defp result_payload(result) do
    %{
      "classification" => Atom.to_string(result.classification),
      "definition_id" => result.id,
      "definition_key" => result.definition_key,
      "descriptor_revision" => result.descriptor_revision,
      "lock_version" => result.lock_version,
      "schema_key" => result.schema_key
    }
  end

  defp decode_result(%{result_payload: payload} = claim) when is_map(payload) do
    with %{
           "classification" => classification,
           "definition_id" => id,
           "definition_key" => definition_key,
           "descriptor_revision" => descriptor_revision,
           "lock_version" => lock_version,
           "schema_key" => schema_key
         } <- payload,
         {:ok, classification} <- classification_atom(classification),
         true <- is_integer(lock_version) and lock_version > 0,
         true <- is_binary(claim.audit_reference) and is_binary(claim.event_id) do
      {:ok,
       %PublishResult{
         audit_reference: claim.audit_reference,
         classification: classification,
         definition_key: definition_key,
         descriptor_revision: descriptor_revision,
         event_id: claim.event_id,
         id: id,
         lock_version: lock_version,
         schema_key: schema_key
       }}
    else
      _invalid -> extension_error(:retryable_dependency)
    end
  end

  defp decode_result(_claim), do: extension_error(:retryable_dependency)

  defp classification_atom("public"), do: {:ok, :public}
  defp classification_atom("internal"), do: {:ok, :internal}
  defp classification_atom("confidential"), do: {:ok, :confidential}
  defp classification_atom("restricted"), do: {:ok, :restricted}
  defp classification_atom(_classification), do: :error

  defp request_hash(arguments, content) do
    {
      @action_name,
      arguments.definition_id,
      arguments.definition_key,
      arguments.schema_key,
      arguments.descriptor_revision,
      content,
      arguments.expected_version,
      arguments.causation_id
    }
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
  end

  defp translate_query_error(%PostgrexError{postgres: %{constraint: constraint}})
       when constraint in [
              "platform_governed_extension_definitions_key_index",
              :platform_governed_extension_definitions_key_index,
              "platform_governed_extension_definitions_pkey",
              :platform_governed_extension_definitions_pkey
            ],
       do: extension_error(:conflict)

  defp translate_query_error(_error), do: extension_error(:retryable_dependency)

  defp cast_uuid(value) do
    case UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> extension_error(:invalid_input)
    end
  end

  defp dump_uuid(value), do: UUID.dump!(value)
  defp extension_error(code), do: {:error, %GovernedExtensionError{code: code}}
end
