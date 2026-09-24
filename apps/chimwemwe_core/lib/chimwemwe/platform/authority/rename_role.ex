defmodule Chimwemwe.Platform.Authority.RenameRole do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  alias Chimwemwe.Platform.{Authority, AuthorityError, TrustedActor}
  alias Chimwemwe.Platform.Authority.RenameRoleResult
  alias Chimwemwe.Repo
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  @action_name "platform.authority.role.rename"
  @aggregate_type "platform.authority.role"
  @event_type "platform.authority.role.renamed"
  @manage_capability "platform.authority.roles.rename"
  @schema_version 1

  @impl true
  def run(input, _options, context) do
    with {:ok, action_context} <- validate_context(context),
         :ok <- lock_authority_writes(action_context.tenant_id),
         :ok <- reauthorize(action_context.actor),
         request_hash <- request_hash(input.arguments),
         {:ok, claim} <- claim(action_context, input.arguments, request_hash) do
      execute_or_replay(action_context, input.arguments, request_hash, claim)
    end
  rescue
    _error -> authority_error(:retryable_dependency)
  catch
    :exit, _reason -> authority_error(:retryable_dependency)
  end

  defp validate_context(%{
         actor: actor,
         tenant: tenant_id,
         source_context: %{
           chimwemwe: %{
             correlation_id: correlation_id,
             routing_version: routing_version
           }
         }
       }) do
    with {:ok, trusted_actor} <- TrustedActor.revalidate(actor),
         true <- tenant_id == TrustedActor.tenant_id(trusted_actor),
         {:ok, correlation_id} <- cast_uuid(correlation_id),
         true <- is_integer(routing_version) and routing_version > 0 do
      {:ok,
       %{
         actor: trusted_actor,
         actor_id: TrustedActor.actor_id(trusted_actor),
         tenant_id: tenant_id,
         correlation_id: correlation_id,
         routing_version: routing_version
       }}
    else
      _invalid -> authority_error(:forbidden)
    end
  end

  defp validate_context(_context), do: authority_error(:forbidden)

  defp lock_authority_writes(tenant_id) do
    case Repo.query(
           "SELECT pg_advisory_xact_lock(hashtextextended('platform-authority-writes:' || $1::text, 0))",
           [tenant_id]
         ) do
      {:ok, _result} -> :ok
      {:error, _error} -> authority_error(:retryable_dependency)
    end
  end

  defp reauthorize(actor) do
    if Authority.actor_has_capability?(actor, @manage_capability) do
      :ok
    else
      authority_error(:forbidden)
    end
  end

  defp claim(context, arguments, request_hash) do
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
             @action_name,
             dump_uuid(arguments.idempotency_key),
             @aggregate_type,
             dump_uuid(arguments.role_id),
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
           SELECT
             id::text,
             actor_id::text,
             aggregate_id::text,
             request_hash,
             status,
             result_name,
             result_lock_version,
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
             id,
             actor_id,
             aggregate_id,
             request_hash,
             status,
             result_name,
             result_lock_version,
             audit_reference,
             event_id
           ]
         ]
       }} ->
        {:ok,
         {:existing,
          %{
            id: id,
            actor_id: actor_id,
            aggregate_id: aggregate_id,
            request_hash: request_hash,
            status: status,
            result_name: result_name,
            result_lock_version: result_lock_version,
            audit_reference: audit_reference,
            event_id: event_id
          }}}

      {:ok, %{rows: []}} ->
        authority_error(:retryable_dependency)

      {:error, error} ->
        translate_query_error(error)
    end
  end

  defp execute_or_replay(context, arguments, request_hash, {:new, claim_id}) do
    execute_rename(context, arguments, claim_id, request_hash)
  end

  defp execute_or_replay(context, arguments, request_hash, {:existing, claim}) do
    if claim.status == "completed" and claim.actor_id == context.actor_id and
         claim.aggregate_id == arguments.role_id and claim.request_hash == request_hash do
      {:ok,
       %RenameRoleResult{
         id: claim.aggregate_id,
         name: claim.result_name,
         lock_version: claim.result_lock_version,
         audit_reference: claim.audit_reference,
         event_id: claim.event_id
       }}
    else
      authority_error(:idempotency_conflict)
    end
  end

  defp execute_rename(context, arguments, claim_id, _request_hash) do
    with {:ok, role} <- lock_role(context.tenant_id, arguments.role_id),
         :ok <- require_version(role.lock_version, arguments.expected_version),
         {:ok, next_version} <-
           persist_rename(context.tenant_id, arguments.role_id, arguments.name, role.lock_version),
         audit_reference <- UUID.generate(),
         event_id <- UUID.generate(),
         :ok <-
           insert_audit(
             context,
             arguments,
             audit_reference,
             role.name,
             next_version
           ),
         :ok <- insert_outbox(context, arguments, audit_reference, event_id, next_version),
         :ok <-
           complete_claim(
             claim_id,
             arguments.name,
             next_version,
             audit_reference,
             event_id
           ) do
      {:ok,
       %RenameRoleResult{
         id: arguments.role_id,
         name: arguments.name,
         lock_version: next_version,
         audit_reference: audit_reference,
         event_id: event_id
       }}
    end
  end

  defp lock_role(tenant_id, role_id) do
    case Repo.query(
           """
           SELECT name, lock_version
           FROM platform_roles
           WHERE tenant_id = $1 AND id = $2
           FOR UPDATE
           """,
           [dump_uuid(tenant_id), dump_uuid(role_id)]
         ) do
      {:ok, %{rows: [[name, lock_version]]}} ->
        {:ok, %{name: name, lock_version: lock_version}}

      {:ok, %{rows: []}} ->
        authority_error(:not_found)

      {:error, error} ->
        translate_query_error(error)
    end
  end

  defp require_version(version, version), do: :ok
  defp require_version(_current_version, _expected_version), do: authority_error(:conflict)

  defp persist_rename(tenant_id, role_id, name, expected_version) do
    case Repo.query(
           """
           UPDATE platform_roles
           SET name = $1,
               lock_version = lock_version + 1,
               updated_at = NOW()
           WHERE tenant_id = $2 AND id = $3 AND lock_version = $4
           RETURNING lock_version
           """,
           [name, dump_uuid(tenant_id), dump_uuid(role_id), expected_version]
         ) do
      {:ok, %{rows: [[next_version]]}} -> {:ok, next_version}
      {:ok, %{rows: []}} -> authority_error(:conflict)
      {:error, error} -> translate_query_error(error)
    end
  end

  defp insert_audit(context, arguments, audit_reference, previous_name, next_version) do
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
             $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11,
             jsonb_build_object('from_name', $12::text, 'to_name', $13::text),
             NOW(), NOW()
           )
           """,
           [
             dump_uuid(audit_reference),
             dump_uuid(context.tenant_id),
             dump_uuid(context.actor_id),
             @action_name,
             @aggregate_type,
             dump_uuid(arguments.role_id),
             dump_uuid(arguments.idempotency_key),
             dump_uuid(context.correlation_id),
             dump_uuid(arguments.causation_id),
             arguments.expected_version,
             next_version,
             previous_name,
             arguments.name
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, error} -> translate_query_error(error)
    end
  end

  defp insert_outbox(context, arguments, audit_reference, event_id, next_version) do
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
             jsonb_build_object('lock_version', $12::bigint), NOW(), NOW()
           )
           """,
           [
             dump_uuid(event_id),
             dump_uuid(context.tenant_id),
             dump_uuid(context.actor_id),
             @aggregate_type,
             dump_uuid(arguments.role_id),
             @event_type,
             @schema_version,
             context.routing_version,
             dump_uuid(context.correlation_id),
             dump_uuid(arguments.causation_id),
             dump_uuid(audit_reference),
             next_version
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, error} -> translate_query_error(error)
    end
  end

  defp complete_claim(claim_id, name, lock_version, audit_reference, event_id) do
    case Repo.query(
           """
           UPDATE platform_authority_action_idempotency
           SET status = 'completed',
               result_name = $2,
               result_lock_version = $3,
               audit_reference = $4,
               event_id = $5,
               completed_at = NOW(),
               updated_at = NOW()
           WHERE id = $1 AND status = 'started'
           """,
           [
             dump_uuid(claim_id),
             name,
             lock_version,
             dump_uuid(audit_reference),
             dump_uuid(event_id)
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:ok, _unexpected} -> authority_error(:retryable_dependency)
      {:error, error} -> translate_query_error(error)
    end
  end

  defp request_hash(arguments) do
    {@action_name, arguments.role_id, arguments.name, arguments.expected_version,
     arguments.causation_id}
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
  end

  defp translate_query_error(%PostgrexError{postgres: %{constraint: constraint}})
       when constraint in [
              "platform_roles_tenant_name_index",
              :platform_roles_tenant_name_index
            ],
       do: authority_error(:conflict)

  defp translate_query_error(_error), do: authority_error(:retryable_dependency)

  defp cast_uuid(value) do
    case UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> authority_error(:invalid_input)
    end
  end

  defp dump_uuid(value), do: UUID.dump!(value)
  defp authority_error(code), do: {:error, %AuthorityError{code: code}}
end
