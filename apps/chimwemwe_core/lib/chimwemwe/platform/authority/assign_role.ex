defmodule Chimwemwe.Platform.Authority.AssignRole do
  @moduledoc false

  use Ash.Resource.Actions.Implementation

  alias Chimwemwe.Platform.{Authority, AuthorityError, TrustedActor}
  alias Chimwemwe.Platform.Authority.AssignRoleResult
  alias Chimwemwe.Repo
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  @action_name "platform.authority.actor_role_assignment.assign"
  @aggregate_type "platform.authority.actor_role_assignment"
  @event_type "platform.authority.actor_role_assignment.created"
  @manage_capability "platform.authority.assignments.create"
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
    assignment_id = UUID.generate()

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
             dump_uuid(assignment_id),
             request_hash
           ]
         ) do
      {:ok, %{rows: [[^claim_id]]}} -> {:ok, {:new, claim_id, assignment_id}}
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
             id,
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
            id: id,
            actor_id: actor_id,
            aggregate_id: aggregate_id,
            request_hash: request_hash,
            status: status,
            result_payload: result_payload,
            audit_reference: audit_reference,
            event_id: event_id
          }}}

      {:ok, %{rows: []}} ->
        authority_error(:retryable_dependency)

      {:error, error} ->
        translate_query_error(error)
    end
  end

  defp execute_or_replay(context, arguments, _request_hash, {:new, claim_id, assignment_id}) do
    execute_assignment(context, arguments, claim_id, assignment_id)
  end

  defp execute_or_replay(context, _arguments, request_hash, {:existing, claim}) do
    if claim.status == "completed" and claim.actor_id == context.actor_id and
         claim.request_hash == request_hash do
      replay_result(claim)
    else
      authority_error(:idempotency_conflict)
    end
  end

  defp replay_result(claim) do
    with %{
           "assignment_id" => assignment_id,
           "membership_id" => membership_id,
           "role_id" => role_id,
           "lock_version" => lock_version
         } <- claim.result_payload,
         {:ok, assignment_id} <- cast_uuid(assignment_id),
         true <- assignment_id == claim.aggregate_id,
         {:ok, membership_id} <- cast_uuid(membership_id),
         {:ok, role_id} <- cast_uuid(role_id),
         true <- lock_version == 1,
         {:ok, audit_reference} <- cast_uuid(claim.audit_reference),
         {:ok, event_id} <- cast_uuid(claim.event_id) do
      {:ok,
       %AssignRoleResult{
         id: assignment_id,
         membership_id: membership_id,
         role_id: role_id,
         lock_version: lock_version,
         audit_reference: audit_reference,
         event_id: event_id
       }}
    else
      _invalid_stored_result -> authority_error(:retryable_dependency)
    end
  end

  defp execute_assignment(context, arguments, claim_id, assignment_id) do
    with :ok <- lock_references(context.tenant_id, arguments.membership_id, arguments.role_id),
         :ok <- insert_assignment(context.tenant_id, assignment_id, arguments),
         audit_reference <- UUID.generate(),
         event_id <- UUID.generate(),
         :ok <- insert_audit(context, arguments, assignment_id, audit_reference),
         :ok <- insert_outbox(context, arguments, assignment_id, audit_reference, event_id),
         :ok <- complete_claim(claim_id, assignment_id, arguments, audit_reference, event_id) do
      {:ok,
       %AssignRoleResult{
         id: assignment_id,
         membership_id: arguments.membership_id,
         role_id: arguments.role_id,
         lock_version: 1,
         audit_reference: audit_reference,
         event_id: event_id
       }}
    end
  end

  defp lock_references(tenant_id, membership_id, role_id) do
    case Repo.query(
           """
           SELECT membership.id::text, role.id::text
           FROM platform_tenant_memberships AS membership
           JOIN platform_roles AS role
             ON role.tenant_id = membership.tenant_id
           WHERE membership.tenant_id = $1
             AND membership.id = $2
             AND role.id = $3
           FOR KEY SHARE OF membership, role
           """,
           [dump_uuid(tenant_id), dump_uuid(membership_id), dump_uuid(role_id)]
         ) do
      {:ok, %{rows: [[^membership_id, ^role_id]]}} -> :ok
      {:ok, %{rows: []}} -> authority_error(:not_found)
      {:error, error} -> translate_query_error(error)
    end
  end

  defp insert_assignment(tenant_id, assignment_id, arguments) do
    case Repo.query(
           """
           INSERT INTO platform_actor_role_assignments (
             id,
             tenant_id,
             membership_id,
             role_id,
             lock_version,
             inserted_at
           )
           VALUES ($1, $2, $3, $4, 1, NOW())
           """,
           [
             dump_uuid(assignment_id),
             dump_uuid(tenant_id),
             dump_uuid(arguments.membership_id),
             dump_uuid(arguments.role_id)
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, error} -> translate_query_error(error)
    end
  end

  defp insert_audit(context, arguments, assignment_id, audit_reference) do
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
             jsonb_build_object('membership_id', $10::uuid, 'role_id', $11::uuid),
             NOW(), NOW()
           )
           """,
           [
             dump_uuid(audit_reference),
             dump_uuid(context.tenant_id),
             dump_uuid(context.actor_id),
             @action_name,
             @aggregate_type,
             dump_uuid(assignment_id),
             dump_uuid(arguments.idempotency_key),
             dump_uuid(context.correlation_id),
             dump_uuid(arguments.causation_id),
             dump_uuid(arguments.membership_id),
             dump_uuid(arguments.role_id)
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, error} -> translate_query_error(error)
    end
  end

  defp insert_outbox(context, arguments, assignment_id, audit_reference, event_id) do
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
               'membership_id', $12::uuid,
               'role_id', $13::uuid,
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
             dump_uuid(assignment_id),
             @event_type,
             @schema_version,
             context.routing_version,
             dump_uuid(context.correlation_id),
             dump_uuid(arguments.causation_id),
             dump_uuid(audit_reference),
             dump_uuid(arguments.membership_id),
             dump_uuid(arguments.role_id)
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, error} -> translate_query_error(error)
    end
  end

  defp complete_claim(claim_id, assignment_id, arguments, audit_reference, event_id) do
    case Repo.query(
           """
           UPDATE platform_authority_action_idempotency
           SET status = 'completed',
               result_payload = jsonb_build_object(
                 'assignment_id', $2::uuid,
                 'membership_id', $3::uuid,
                 'role_id', $4::uuid,
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
             dump_uuid(assignment_id),
             dump_uuid(arguments.membership_id),
             dump_uuid(arguments.role_id),
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
    {@action_name, arguments.membership_id, arguments.role_id, arguments.causation_id}
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
  end

  defp translate_query_error(%PostgrexError{postgres: %{constraint: constraint}})
       when constraint in [
              "platform_actor_role_assignments_unique_index",
              :platform_actor_role_assignments_unique_index
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
