defmodule Chimwemwe.Identity.Foundation do
  @moduledoc """
  Internal provider-neutral identity, invitation, and account-link boundary.

  All writes require a validated execution context, current tenant capability
  where applicable, writer routing, idempotency, audit, and outbox evidence.
  No function accepts provider groups, provider roles, email matching, a tenant
  database, or placement coordinates.
  """

  alias Chimwemwe.Identity.{
    ConnectionResult,
    Error,
    Evidence,
    InternalWriter,
    InvitationResult,
    LinkResult
  }

  alias Chimwemwe.Identity.VerifiedExternalIdentity

  alias Chimwemwe.Platform.Authority
  alias Chimwemwe.Repo
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  @connection_capability "identity.connections.manage"
  @invitation_capability "identity.invitations.issue"
  @connection_aggregate "identity.connection"
  @invitation_aggregate "identity.invitation"
  @link_aggregate "identity.external_identity_link"
  @protocols [:oidc, :saml]
  @connection_register_keys [
    :application_identifier,
    :assurance_mapping,
    :causation_id,
    :idempotency_key,
    :issuer,
    :name,
    :protocol,
    :secret_reference
  ]
  @transition_keys [:causation_id, :connection_id, :expected_version, :idempotency_key]
  @invitation_keys [
    :actor_id,
    :causation_id,
    :connection_id,
    :idempotency_key,
    :membership_id,
    :role_id
  ]
  @acceptance_keys [:causation_id, :idempotency_key, :proof, :token]

  @doc "Registers an internal draft connection without contacting a provider."
  @spec register_connection(Supervisor.supervisor(), term(), map()) ::
          {:ok, ConnectionResult.t()} | {:error, term()}
  def register_connection(runtime, context, input) do
    with {:ok, input} <- normalize_connection_input(input) do
      write(runtime, context, &register_connection_write(&1, input))
    end
  end

  @doc "Qualifies a fully reviewed draft connection configuration."
  def qualify_connection(runtime, context, input),
    do: transition_connection(runtime, context, input, :qualified, [:draft])

  @doc "Activates a qualified connection for later trusted adapters."
  def activate_connection(runtime, context, input),
    do: transition_connection(runtime, context, input, :active, [:qualified])

  @doc "Suspends an active connection without deleting retained evidence."
  def suspend_connection(runtime, context, input),
    do: transition_connection(runtime, context, input, :suspended, [:active])

  @doc "Retires a connection permanently from future authentication."
  def retire_connection(runtime, context, input),
    do: transition_connection(runtime, context, input, :retired, [:draft, :qualified, :suspended])

  @doc "Issues one deterministic-on-retry, single-use 30-minute invitation token."
  @spec issue_invitation(Supervisor.supervisor(), term(), map()) ::
          {:ok, InvitationResult.t()} | {:error, term()}
  def issue_invitation(runtime, context, input) do
    with {:ok, input} <- normalize_invitation_input(input) do
      write(runtime, context, &issue_invitation_write(&1, input))
    end
  end

  @doc "Consumes one invitation and creates exactly one stable external identity link."
  @spec accept_invitation(Supervisor.supervisor(), term(), map()) ::
          {:ok, LinkResult.t()} | {:error, term()}
  def accept_invitation(runtime, context, input) do
    with {:ok, input} <- normalize_acceptance_input(input),
         :ok <- VerifiedExternalIdentity.validate(input.proof),
         :ok <- fresh_proof(input.proof) do
      write(runtime, context, &accept_invitation_write(&1, input))
    end
  end

  defp transition_connection(runtime, context, input, next_status, allowed_statuses) do
    with {:ok, input} <- normalize_transition_input(input) do
      write(
        runtime,
        context,
        &transition_connection_write(&1, input, next_status, allowed_statuses)
      )
    end
  end

  defp register_connection_write(context, input) do
    with :ok <- authorize(context.actor, @connection_capability),
         :ok <- lock_identity_writes(context.tenant_id) do
      register_connection_transaction(context, input)
    end
  end

  defp issue_invitation_write(context, input) do
    with :ok <- authorize(context.actor, @invitation_capability),
         :ok <- lock_identity_writes(context.tenant_id),
         {:ok, secret} <- invitation_secret() do
      issue_invitation_transaction(context, input, secret)
    end
  end

  defp accept_invitation_write(context, input) do
    with :ok <- lock_identity_writes(context.tenant_id) do
      accept_invitation_transaction(context, input)
    end
  end

  defp transition_connection_write(context, input, next_status, allowed_statuses) do
    with :ok <- authorize(context.actor, @connection_capability),
         :ok <- lock_identity_writes(context.tenant_id) do
      transition_connection_transaction(context, input, next_status, allowed_statuses)
    end
  end

  defp register_connection_transaction(context, input) do
    action_name = "identity.connection.register"
    connection_id = UUID.generate()
    request_hash = request_hash(action_name, input)

    with {:ok, claim} <-
           Evidence.claim(
             context,
             action_name,
             @connection_aggregate,
             input.idempotency_key,
             request_hash,
             connection_id
           ) do
      case claim do
        {:existing, stored} ->
          replay_connection(stored, context.actor_id, request_hash)

        {:new, claim_id} ->
          create_connection(context, input, connection_id, claim_id, action_name)
      end
    end
  end

  defp create_connection(context, input, connection_id, claim_id, action_name) do
    case Repo.query(
           """
           INSERT INTO identity_connections (
             id, tenant_id, name, protocol, issuer, application_identifier,
             secret_reference, assurance_mapping, configuration_version,
             status, lock_version, inserted_at, updated_at
           )
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb, 1, 'draft', 1,
                   (NOW() AT TIME ZONE 'utc'), (NOW() AT TIME ZONE 'utc'))
           """,
           [
             dump_uuid(connection_id),
             dump_uuid(context.tenant_id),
             input.name,
             Atom.to_string(input.protocol),
             input.issuer,
             input.application_identifier,
             input.secret_reference,
             input.assurance_mapping
           ]
         ) do
      {:ok, %{num_rows: 1}} ->
        result_payload = connection_payload(connection_id, :draft, 1, 1)

        with {:ok, evidence} <-
               Evidence.record(context, %{
                 action_name: action_name,
                 aggregate_type: @connection_aggregate,
                 aggregate_id: connection_id,
                 idempotency_key: input.idempotency_key,
                 causation_id: input.causation_id,
                 before_version: 0,
                 after_version: 1,
                 change_summary: %{
                   "protocol" => Atom.to_string(input.protocol),
                   "status" => "draft"
                 },
                 event_type: "identity.connection.registered",
                 event_payload: result_payload,
                 result_payload: result_payload,
                 claim_id: claim_id
               }) do
          connection_result(result_payload, evidence)
        end

      {:error, error} ->
        translate_query_error(error)
    end
  end

  defp transition_connection_transaction(context, input, next_status, allowed_statuses) do
    action_name = "identity.connection.#{next_status}"
    request_hash = request_hash(action_name, input)

    with {:ok, claim} <-
           Evidence.claim(
             context,
             action_name,
             @connection_aggregate,
             input.idempotency_key,
             request_hash,
             input.connection_id
           ) do
      case claim do
        {:existing, stored} ->
          replay_connection(stored, context.actor_id, request_hash)

        {:new, claim_id} ->
          update_connection(context, input, next_status, allowed_statuses, claim_id, action_name)
      end
    end
  end

  defp update_connection(context, input, next_status, allowed_statuses, claim_id, action_name) do
    with {:ok, current_status, current_version, configuration_version} <-
           lock_connection(context.tenant_id, input.connection_id),
         :ok <- ensure(current_version == input.expected_version, :stale),
         :ok <- ensure(current_status in allowed_statuses, :conflict),
         {:ok, next_version} <-
           persist_connection_transition(
             context.tenant_id,
             input.connection_id,
             next_status,
             current_version
           ) do
      result_payload =
        connection_payload(input.connection_id, next_status, configuration_version, next_version)

      with {:ok, evidence} <-
             Evidence.record(context, %{
               action_name: action_name,
               aggregate_type: @connection_aggregate,
               aggregate_id: input.connection_id,
               idempotency_key: input.idempotency_key,
               causation_id: input.causation_id,
               before_version: current_version,
               after_version: next_version,
               change_summary: %{
                 "from" => Atom.to_string(current_status),
                 "to" => Atom.to_string(next_status)
               },
               event_type: "identity.connection.#{next_status}",
               event_payload: result_payload,
               result_payload: result_payload,
               claim_id: claim_id
             }) do
        connection_result(result_payload, evidence)
      end
    end
  end

  defp issue_invitation_transaction(context, input, secret) do
    action_name = "identity.invitation.issue"
    invitation_id = UUID.generate()
    request_hash = request_hash(action_name, input)

    with {:ok, claim} <-
           Evidence.claim(
             context,
             action_name,
             @invitation_aggregate,
             input.idempotency_key,
             request_hash,
             invitation_id
           ) do
      case claim do
        {:existing, stored} ->
          replay_invitation(
            stored,
            context.actor_id,
            context.tenant_id,
            request_hash,
            secret,
            input.idempotency_key
          )

        {:new, claim_id} ->
          create_invitation(context, input, secret, invitation_id, claim_id, action_name)
      end
    end
  end

  defp create_invitation(context, input, secret, invitation_id, claim_id, action_name) do
    token = invitation_token(secret, context.tenant_id, input.idempotency_key, invitation_id)
    token_digest = token_digest(token)

    with :ok <- lock_invitation_references(context.tenant_id, input),
         {:ok, expires_at} <-
           insert_invitation(context.tenant_id, input, invitation_id, token_digest) do
      result_payload = %{
        "invitation_id" => invitation_id,
        "expires_at" => DateTime.to_iso8601(expires_at)
      }

      with {:ok, evidence} <-
             Evidence.record(context, %{
               action_name: action_name,
               aggregate_type: @invitation_aggregate,
               aggregate_id: invitation_id,
               idempotency_key: input.idempotency_key,
               causation_id: input.causation_id,
               before_version: 0,
               after_version: 1,
               change_summary: %{
                 "connection_id" => input.connection_id,
                 "membership_id" => input.membership_id,
                 "status" => "pending"
               },
               event_type: "identity.invitation.issued",
               event_payload: %{
                 "invitation_id" => invitation_id,
                 "membership_id" => input.membership_id,
                 "expires_at" => DateTime.to_iso8601(expires_at)
               },
               result_payload: result_payload,
               claim_id: claim_id
             }) do
        {:ok,
         %InvitationResult{
           id: invitation_id,
           token: token,
           expires_at: expires_at,
           audit_reference: evidence.audit_reference,
           event_id: evidence.event_id
         }}
      end
    end
  end

  defp accept_invitation_transaction(context, input) do
    action_name = "identity.invitation.accept"
    digest = token_digest(input.token)

    hash_input = %{
      causation_id: input.causation_id,
      digest: digest,
      proof: proof_hash_input(input.proof)
    }

    request_hash = request_hash(action_name, hash_input)
    link_id = UUID.generate()

    with {:ok, claim} <-
           Evidence.claim(
             context,
             action_name,
             @link_aggregate,
             input.idempotency_key,
             request_hash,
             link_id
           ) do
      case claim do
        {:existing, stored} -> replay_link(stored, context.actor_id, request_hash)
        {:new, claim_id} -> create_link(context, input, digest, link_id, claim_id, action_name)
      end
    end
  end

  defp create_link(context, input, digest, link_id, claim_id, action_name) do
    with {:ok, invitation} <- lock_invitation(context.tenant_id, digest),
         :ok <- validate_invitation(invitation, context, input.proof),
         :ok <- insert_external_link(context.tenant_id, input.proof, invitation, link_id),
         :ok <- consume_invitation(context.tenant_id, invitation.id, link_id) do
      result_payload = %{
        "link_id" => link_id,
        "invitation_id" => invitation.id,
        "actor_id" => invitation.actor_id
      }

      with {:ok, evidence} <-
             Evidence.record(context, %{
               action_name: action_name,
               aggregate_type: @link_aggregate,
               aggregate_id: link_id,
               idempotency_key: input.idempotency_key,
               causation_id: input.causation_id,
               before_version: 0,
               after_version: 1,
               change_summary: %{
                 "invitation_id" => invitation.id,
                 "status" => "active"
               },
               event_type: "identity.external_identity_link.created",
               event_payload: result_payload,
               result_payload: result_payload,
               claim_id: claim_id
             }) do
        {:ok,
         %LinkResult{
           id: link_id,
           invitation_id: invitation.id,
           actor_id: invitation.actor_id,
           audit_reference: evidence.audit_reference,
           event_id: evidence.event_id
         }}
      end
    end
  end

  defp lock_invitation_references(tenant_id, input) do
    case Repo.query(
           """
           SELECT membership.id::text, role.id::text, connection.id::text
           FROM platform_tenant_memberships AS membership
           JOIN platform_actor_role_assignments AS assignment
             ON assignment.tenant_id = membership.tenant_id
            AND assignment.membership_id = membership.id
           JOIN platform_roles AS role
             ON role.tenant_id = assignment.tenant_id
            AND role.id = assignment.role_id
           JOIN identity_connections AS connection
             ON connection.tenant_id = membership.tenant_id
           WHERE membership.tenant_id = $1
             AND membership.id = $2
             AND membership.actor_id = $3
             AND role.id = $4
             AND connection.id = $5
             AND connection.status = 'active'
           FOR KEY SHARE OF membership, assignment, role, connection
           """,
           [
             dump_uuid(tenant_id),
             dump_uuid(input.membership_id),
             dump_uuid(input.actor_id),
             dump_uuid(input.role_id),
             dump_uuid(input.connection_id)
           ]
         ) do
      {:ok, %{rows: [[_membership, _role, _connection]]}} -> :ok
      {:ok, %{rows: []}} -> error(:not_found)
      {:error, _error} -> error(:retryable_dependency)
    end
  end

  defp insert_invitation(tenant_id, input, invitation_id, token_digest) do
    case Repo.query(
           """
           INSERT INTO identity_invitations (
             id, tenant_id, actor_id, membership_id, role_id, connection_id,
             token_digest, status, expires_at, lock_version, inserted_at, updated_at
           )
           VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending',
                   (NOW() AT TIME ZONE 'utc') + INTERVAL '30 minutes', 1,
                   (NOW() AT TIME ZONE 'utc'), (NOW() AT TIME ZONE 'utc'))
           RETURNING expires_at
           """,
           [
             dump_uuid(invitation_id),
             dump_uuid(tenant_id),
             dump_uuid(input.actor_id),
             dump_uuid(input.membership_id),
             dump_uuid(input.role_id),
             dump_uuid(input.connection_id),
             token_digest
           ]
         ) do
      {:ok, %{rows: [[%NaiveDateTime{} = expires_at]]}} ->
        {:ok, DateTime.from_naive!(expires_at, "Etc/UTC")}

      {:error, error} ->
        translate_query_error(error)
    end
  end

  defp lock_invitation(tenant_id, digest) do
    case Repo.query(
           """
           SELECT invitation.id::text, invitation.actor_id::text,
                  invitation.membership_id::text, invitation.role_id::text,
                  invitation.connection_id::text, invitation.status,
                  invitation.expires_at, connection.protocol, connection.issuer,
                  connection.configuration_version, connection.status,
                  EXISTS (
                    SELECT 1
                    FROM platform_tenant_memberships AS membership
                    JOIN platform_actor_role_assignments AS assignment
                      ON assignment.tenant_id = membership.tenant_id
                     AND assignment.membership_id = membership.id
                    WHERE membership.tenant_id = invitation.tenant_id
                      AND membership.id = invitation.membership_id
                      AND membership.actor_id = invitation.actor_id
                      AND assignment.role_id = invitation.role_id
                  ) AS authority_current
           FROM identity_invitations AS invitation
           JOIN identity_connections AS connection
             ON connection.tenant_id = invitation.tenant_id
            AND connection.id = invitation.connection_id
           WHERE invitation.tenant_id = $1 AND invitation.token_digest = $2
           FOR UPDATE OF invitation, connection
           """,
           [dump_uuid(tenant_id), digest]
         ) do
      {:ok,
       %{
         rows: [
           [
             id,
             actor_id,
             membership_id,
             role_id,
             connection_id,
             status,
             expires_at,
             protocol,
             issuer,
             configuration_version,
             connection_status,
             authority_current
           ]
         ]
       }} ->
        {:ok,
         %{
           id: id,
           actor_id: actor_id,
           membership_id: membership_id,
           role_id: role_id,
           connection_id: connection_id,
           status: status,
           expires_at: expires_at,
           protocol: protocol,
           issuer: issuer,
           configuration_version: configuration_version,
           connection_status: connection_status,
           authority_current: authority_current
         }}

      {:ok, %{rows: []}} ->
        error(:not_found)

      {:error, _error} ->
        error(:retryable_dependency)
    end
  end

  defp validate_invitation(invitation, context, proof) do
    now = DateTime.utc_now() |> DateTime.to_naive()

    with :ok <- validate_invitation_state(invitation, now),
         :ok <- ensure(invitation.actor_id == context.actor_id, :forbidden),
         :ok <- validate_invitation_connection(invitation, proof) do
      ensure(invitation.authority_current == true, :forbidden)
    end
  end

  defp validate_invitation_state(invitation, now) do
    cond do
      invitation.status != "pending" -> error(:conflict)
      NaiveDateTime.compare(invitation.expires_at, now) != :gt -> error(:expired)
      true -> :ok
    end
  end

  defp validate_invitation_connection(invitation, proof) do
    cond do
      invitation.connection_id != proof.connection_id -> error(:forbidden)
      invitation.connection_status != "active" -> error(:forbidden)
      invitation.protocol != Atom.to_string(proof.protocol) -> error(:forbidden)
      invitation.issuer != proof.issuer -> error(:forbidden)
      true -> :ok
    end
  end

  defp insert_external_link(tenant_id, proof, invitation, link_id) do
    case Repo.query(
           """
           INSERT INTO identity_external_identity_links (
             id, actor_id, origin_tenant_id, connection_id, protocol, issuer,
             subject, connection_configuration_version, status, lock_version,
             inserted_at, updated_at
           )
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'active', 1,
                   (NOW() AT TIME ZONE 'utc'), (NOW() AT TIME ZONE 'utc'))
           """,
           [
             dump_uuid(link_id),
             dump_uuid(invitation.actor_id),
             dump_uuid(tenant_id),
             dump_uuid(proof.connection_id),
             Atom.to_string(proof.protocol),
             proof.issuer,
             proof.subject,
             invitation.configuration_version
           ]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, error} -> translate_query_error(error)
    end
  end

  defp consume_invitation(tenant_id, invitation_id, link_id) do
    case Repo.query(
           """
           UPDATE identity_invitations
           SET status = 'accepted', accepted_at = (NOW() AT TIME ZONE 'utc'),
               external_identity_link_id = $3, lock_version = lock_version + 1,
               updated_at = (NOW() AT TIME ZONE 'utc')
           WHERE tenant_id = $1 AND id = $2 AND status = 'pending'
           """,
           [dump_uuid(tenant_id), dump_uuid(invitation_id), dump_uuid(link_id)]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:ok, _not_updated} -> error(:conflict)
      {:error, _error} -> error(:retryable_dependency)
    end
  end

  defp lock_connection(tenant_id, connection_id) do
    case Repo.query(
           """
           SELECT status, lock_version, configuration_version
           FROM identity_connections
           WHERE tenant_id = $1 AND id = $2
           FOR UPDATE
           """,
           [dump_uuid(tenant_id), dump_uuid(connection_id)]
         ) do
      {:ok, %{rows: [[status, lock_version, configuration_version]]}} ->
        {:ok, String.to_existing_atom(status), lock_version, configuration_version}

      {:ok, %{rows: []}} ->
        error(:not_found)

      {:error, _error} ->
        error(:retryable_dependency)
    end
  end

  defp persist_connection_transition(tenant_id, connection_id, next_status, current_version) do
    qualified_at =
      if next_status == :qualified, do: ", qualified_at = (NOW() AT TIME ZONE 'utc')", else: ""

    case Repo.query(
           """
           UPDATE identity_connections
           SET status = $3, lock_version = lock_version + 1,
               updated_at = (NOW() AT TIME ZONE 'utc')#{qualified_at}
           WHERE tenant_id = $1 AND id = $2 AND lock_version = $4
           RETURNING lock_version
           """,
           [
             dump_uuid(tenant_id),
             dump_uuid(connection_id),
             Atom.to_string(next_status),
             current_version
           ]
         ) do
      {:ok, %{rows: [[next_version]]}} -> {:ok, next_version}
      {:ok, %{rows: []}} -> error(:stale)
      {:error, _error} -> error(:retryable_dependency)
    end
  end

  defp replay_connection(stored, actor_id, request_hash) do
    with {:ok, claim} <- Evidence.replay(stored, actor_id, request_hash),
         %{
           "connection_id" => connection_id,
           "status" => status,
           "configuration_version" => configuration_version,
           "lock_version" => lock_version
         } <- claim.result_payload,
         {:ok, connection_id} <- cast_uuid(connection_id),
         true <- connection_id == claim.aggregate_id,
         {:ok, status} <- known_status(status),
         true <- positive?(configuration_version) and positive?(lock_version),
         {:ok, audit_reference} <- cast_uuid(claim.audit_reference),
         {:ok, event_id} <- cast_uuid(claim.event_id) do
      {:ok,
       %ConnectionResult{
         id: connection_id,
         status: status,
         configuration_version: configuration_version,
         lock_version: lock_version,
         audit_reference: audit_reference,
         event_id: event_id
       }}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      _invalid -> error(:retryable_dependency)
    end
  end

  defp replay_invitation(
         stored,
         actor_id,
         tenant_id,
         request_hash,
         secret,
         idempotency_key
       ) do
    with {:ok, claim} <- Evidence.replay(stored, actor_id, request_hash),
         %{"invitation_id" => invitation_id, "expires_at" => expires_at} <- claim.result_payload,
         {:ok, invitation_id} <- cast_uuid(invitation_id),
         true <- invitation_id == claim.aggregate_id,
         {:ok, expires_at, 0} <- DateTime.from_iso8601(expires_at),
         {:ok, audit_reference} <- cast_uuid(claim.audit_reference),
         {:ok, event_id} <- cast_uuid(claim.event_id) do
      {:ok,
       %InvitationResult{
         id: invitation_id,
         token: invitation_token(secret, tenant_id, idempotency_key, invitation_id),
         expires_at: expires_at,
         audit_reference: audit_reference,
         event_id: event_id
       }}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      _invalid -> error(:retryable_dependency)
    end
  end

  defp replay_link(stored, actor_id, request_hash) do
    with {:ok, claim} <- Evidence.replay(stored, actor_id, request_hash),
         %{
           "link_id" => link_id,
           "invitation_id" => invitation_id,
           "actor_id" => linked_actor_id
         } <- claim.result_payload,
         {:ok, link_id} <- cast_uuid(link_id),
         true <- link_id == claim.aggregate_id,
         {:ok, invitation_id} <- cast_uuid(invitation_id),
         {:ok, linked_actor_id} <- cast_uuid(linked_actor_id),
         {:ok, audit_reference} <- cast_uuid(claim.audit_reference),
         {:ok, event_id} <- cast_uuid(claim.event_id) do
      {:ok,
       %LinkResult{
         id: link_id,
         invitation_id: invitation_id,
         actor_id: linked_actor_id,
         audit_reference: audit_reference,
         event_id: event_id
       }}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      _invalid -> error(:retryable_dependency)
    end
  end

  defp connection_result(payload, evidence) do
    {:ok,
     %ConnectionResult{
       id: payload["connection_id"],
       status: String.to_existing_atom(payload["status"]),
       configuration_version: payload["configuration_version"],
       lock_version: payload["lock_version"],
       audit_reference: evidence.audit_reference,
       event_id: evidence.event_id
     }}
  end

  defp connection_payload(id, status, configuration_version, lock_version) do
    %{
      "connection_id" => id,
      "status" => Atom.to_string(status),
      "configuration_version" => configuration_version,
      "lock_version" => lock_version
    }
  end

  defp write(runtime, context, operation) do
    InternalWriter.run(runtime, context, operation)
  end

  defp authorize(actor, capability) do
    if Authority.actor_has_capability?(actor, capability), do: :ok, else: error(:forbidden)
  end

  defp lock_identity_writes(tenant_id) do
    case Repo.query(
           "SELECT pg_advisory_xact_lock(hashtextextended('identity-writes:' || $1::text, 0))",
           [tenant_id]
         ) do
      {:ok, _result} -> :ok
      {:error, _error} -> error(:retryable_dependency)
    end
  end

  defp normalize_connection_input(input) do
    with {:ok, input} <- exact_input(input, @connection_register_keys),
         {:ok, name} <- bounded_string(input.name, 3, 120),
         protocol when protocol in @protocols <- input.protocol,
         {:ok, issuer} <- bounded_string(input.issuer, 1, 500),
         {:ok, application_identifier} <- bounded_string(input.application_identifier, 1, 500),
         {:ok, secret_reference} <- bounded_string(input.secret_reference, 3, 500),
         {:ok, assurance_mapping} <- assurance_mapping(input.assurance_mapping),
         {:ok, idempotency_key} <- cast_uuid(input.idempotency_key),
         {:ok, causation_id} <- cast_uuid(input.causation_id) do
      {:ok,
       %{
         name: name,
         protocol: protocol,
         issuer: normalize_identifier(issuer),
         application_identifier: application_identifier,
         secret_reference: secret_reference,
         assurance_mapping: assurance_mapping,
         idempotency_key: idempotency_key,
         causation_id: causation_id
       }}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      _invalid -> error(:invalid_input)
    end
  end

  defp normalize_transition_input(input) do
    with {:ok, input} <- exact_input(input, @transition_keys),
         {:ok, connection_id} <- cast_uuid(input.connection_id),
         true <- positive?(input.expected_version),
         {:ok, idempotency_key} <- cast_uuid(input.idempotency_key),
         {:ok, causation_id} <- cast_uuid(input.causation_id) do
      {:ok,
       %{
         connection_id: connection_id,
         expected_version: input.expected_version,
         idempotency_key: idempotency_key,
         causation_id: causation_id
       }}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      _invalid -> error(:invalid_input)
    end
  end

  defp normalize_invitation_input(input) do
    with {:ok, input} <- exact_input(input, @invitation_keys),
         {:ok, actor_id} <- cast_uuid(input.actor_id),
         {:ok, membership_id} <- cast_uuid(input.membership_id),
         {:ok, role_id} <- cast_uuid(input.role_id),
         {:ok, connection_id} <- cast_uuid(input.connection_id),
         {:ok, idempotency_key} <- cast_uuid(input.idempotency_key),
         {:ok, causation_id} <- cast_uuid(input.causation_id) do
      {:ok,
       %{
         actor_id: actor_id,
         membership_id: membership_id,
         role_id: role_id,
         connection_id: connection_id,
         idempotency_key: idempotency_key,
         causation_id: causation_id
       }}
    end
  end

  defp normalize_acceptance_input(input) do
    with {:ok, input} <- exact_input(input, @acceptance_keys),
         true <- match?(%VerifiedExternalIdentity{}, input.proof),
         {:ok, token} <- bounded_string(input.token, 20, 500),
         {:ok, idempotency_key} <- cast_uuid(input.idempotency_key),
         {:ok, causation_id} <- cast_uuid(input.causation_id) do
      {:ok,
       %{
         proof: input.proof,
         token: token,
         idempotency_key: idempotency_key,
         causation_id: causation_id
       }}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      _invalid -> error(:invalid_input)
    end
  end

  defp exact_input(input, keys) when is_map(input) and not is_struct(input) do
    Enum.reduce_while(input, {:ok, %{}}, fn {key, value}, {:ok, normalized} ->
      normalized_key = normalize_key(key, keys)

      if normalized_key && not Map.has_key?(normalized, normalized_key) do
        {:cont, {:ok, Map.put(normalized, normalized_key, value)}}
      else
        {:halt, error(:invalid_input)}
      end
    end)
    |> case do
      {:ok, normalized} when map_size(normalized) == length(keys) -> {:ok, normalized}
      {:ok, _missing} -> error(:invalid_input)
      {:error, _error} = error_result -> error_result
    end
  end

  defp exact_input(_input, _keys), do: error(:invalid_input)

  defp normalize_key(key, keys) when is_atom(key), do: if(key in keys, do: key)

  defp normalize_key(key, keys) when is_binary(key) do
    Enum.find(keys, &(Atom.to_string(&1) == key))
  end

  defp normalize_key(_key, _keys), do: nil

  defp assurance_mapping(value) when is_map(value) and not is_struct(value) do
    valid? =
      map_size(value) <= 20 and
        Enum.all?(value, fn {key, mapped} ->
          is_binary(key) and is_binary(mapped) and String.length(key) in 1..120 and
            String.length(mapped) in 1..120
        end)

    if valid?, do: {:ok, value}, else: error(:invalid_input)
  end

  defp assurance_mapping(_value), do: error(:invalid_input)

  defp bounded_string(value, minimum, maximum) when is_binary(value) do
    trimmed = String.trim(value)
    length = String.length(trimmed)
    if length >= minimum and length <= maximum, do: {:ok, trimmed}, else: error(:invalid_input)
  end

  defp bounded_string(_value, _minimum, _maximum), do: error(:invalid_input)

  defp invitation_secret do
    case Application.get_env(:chimwemwe_core, :identity_invitation_hmac_secret) do
      secret when is_binary(secret) and byte_size(secret) >= 32 -> {:ok, secret}
      _missing_or_short -> error(:retryable_dependency)
    end
  end

  defp invitation_token(secret, tenant_id, idempotency_key, invitation_id) do
    data = Enum.join([tenant_id, idempotency_key, invitation_id], ":")

    :crypto.mac(:hmac, :sha256, secret, data)
    |> Base.url_encode64(padding: false)
  end

  defp token_digest(token), do: :crypto.hash(:sha256, token)

  defp request_hash(action_name, input) do
    {action_name, input}
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
  end

  defp proof_hash_input(proof) do
    Map.take(proof, [:connection_id, :protocol, :issuer, :subject, :assurance, :authenticated_at])
  end

  defp fresh_proof(proof) do
    now = DateTime.utc_now()
    oldest = DateTime.add(now, -10 * 60, :second)
    newest = DateTime.add(now, 60, :second)

    if DateTime.compare(proof.authenticated_at, oldest) in [:eq, :gt] and
         DateTime.compare(proof.authenticated_at, newest) in [:eq, :lt] do
      :ok
    else
      error(:forbidden)
    end
  end

  defp normalize_identifier(value), do: String.trim(value)

  defp known_status(status) when is_binary(status) do
    case status do
      "draft" -> {:ok, :draft}
      "qualified" -> {:ok, :qualified}
      "active" -> {:ok, :active}
      "suspended" -> {:ok, :suspended}
      "retired" -> {:ok, :retired}
      _unknown -> error(:retryable_dependency)
    end
  end

  defp positive?(value), do: is_integer(value) and value > 0

  defp ensure(true, _code), do: :ok
  defp ensure(false, code), do: error(code)

  defp cast_uuid(value) do
    case UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      _invalid -> error(:invalid_input)
    end
  end

  defp translate_query_error(%PostgrexError{postgres: %{constraint: constraint}})
       when constraint in [
              :identity_connections_tenant_name_index,
              "identity_connections_tenant_name_index",
              :identity_external_identity_links_external_key_index,
              "identity_external_identity_links_external_key_index",
              :identity_invitations_token_digest_index,
              "identity_invitations_token_digest_index"
            ],
       do: error(:conflict)

  defp translate_query_error(_error), do: error(:retryable_dependency)

  defp dump_uuid(value), do: UUID.dump!(value)
  defp error(code), do: {:error, %Error{code: code}}
end
