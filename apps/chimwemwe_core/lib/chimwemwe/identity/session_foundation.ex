defmodule Chimwemwe.Identity.SessionFoundation do
  @moduledoc """
  Internal opaque-session and writer-resolved tenant-membership boundary.

  This L0 boundary accepts only a validated server execution context. A visible
  tenant choice is represented by the membership requested for rotation; the
  writer rechecks that membership and never accepts placement coordinates.
  """

  alias Chimwemwe.Identity.{Error, Evidence, InternalWriter, SessionResult, SessionView}
  alias Chimwemwe.Identity.VerifiedExternalIdentity
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @aggregate "identity.application_session"
  @create_keys [
    :causation_id,
    :external_identity_link_id,
    :idempotency_key,
    :membership_id,
    :proof
  ]
  @rotate_keys [:causation_id, :idempotency_key, :membership_id, :token]
  @state_keys [:causation_id, :idempotency_key, :token]
  @validate_keys [:token]

  @doc "Creates a tenant-selected opaque session after link and membership revalidation."
  @spec create(Supervisor.supervisor(), term(), map()) ::
          {:ok, SessionResult.t()} | {:error, term()}
  def create(runtime, context, input) do
    with {:ok, input} <- normalize_create(input),
         :ok <- VerifiedExternalIdentity.validate(input.proof),
         :ok <- fresh_assurance(input.proof.authenticated_at) do
      write(runtime, context, &create_write(&1, input))
    end
  end

  @doc "Rotates a session only after the target writer confirms current membership."
  @spec rotate_for_tenant(Supervisor.supervisor(), term(), map()) ::
          {:ok, SessionResult.t()} | {:error, term()}
  def rotate_for_tenant(runtime, context, input) do
    with {:ok, input} <- normalize_rotate(input) do
      write(runtime, context, &rotate_write(&1, input))
    end
  end

  @doc "Rechecks one opaque session on its authoritative writer and refreshes idle expiry."
  @spec validate(Supervisor.supervisor(), term(), map()) ::
          {:ok, SessionView.t()} | {:error, term()}
  def validate(runtime, context, input) do
    with {:ok, input} <- exact_input(input, @validate_keys),
         {:ok, token} <- token(input.token) do
      write(runtime, context, &validate_write(&1, token))
    end
  end

  @doc "Logs out one exact session and makes its token unusable."
  def logout(runtime, context, input), do: end_session(runtime, context, input, :logged_out)

  @doc "Revokes one exact session and makes its token unusable."
  def revoke(runtime, context, input), do: end_session(runtime, context, input, :revoked)

  @doc "Revokes every active session for the current actor in the selected tenant."
  def revoke_actor_sessions(runtime, context, input) do
    with {:ok, input} <- exact_input(input, [:causation_id, :idempotency_key]),
         {:ok, idempotency_key} <- uuid(input.idempotency_key),
         {:ok, causation_id} <- uuid(input.causation_id) do
      write(
        runtime,
        context,
        &revoke_actor_write(&1, idempotency_key, causation_id)
      )
    end
  end

  defp create_write(context, input) do
    with :ok <- lock_writes(context.tenant_id) do
      create_transaction(context, input)
    end
  end

  defp rotate_write(context, input) do
    with :ok <- lock_writes(context.tenant_id) do
      rotate_transaction(context, input)
    end
  end

  defp validate_write(context, token) do
    with :ok <- lock_writes(context.tenant_id),
         {:ok, session} <- lock_session(context.tenant_id, token_digest(token)),
         :ok <- validate_current_session(session, context),
         {:ok, idle_expires_at, lock_version} <- refresh_idle(session) do
      {:ok, session_view(session, idle_expires_at, lock_version)}
    end
  end

  defp revoke_actor_write(context, idempotency_key, causation_id) do
    with :ok <- lock_writes(context.tenant_id) do
      revoke_actor_transaction(context, idempotency_key, causation_id)
    end
  end

  defp create_transaction(context, input) do
    action_name = "identity.application_session.create"
    session_id = UUID.generate()
    request_hash = request_hash(action_name, input)

    with {:ok, claim} <-
           Evidence.claim(
             context,
             action_name,
             @aggregate,
             input.idempotency_key,
             request_hash,
             session_id
           ) do
      case claim do
        {:existing, stored} ->
          replay_session(stored, context, request_hash, input.idempotency_key)

        {:new, claim_id} ->
          create_session(context, input, session_id, claim_id, action_name)
      end
    end
  end

  defp create_session(context, input, session_id, claim_id, action_name) do
    with {:ok, secret} <- session_secret(),
         :ok <- validate_create_references(context, input),
         token <- session_token(secret, context.tenant_id, input.idempotency_key, session_id),
         {:ok, times} <- insert_session(context, input, session_id, token_digest(token)),
         result_payload <- session_payload(context, input, session_id, times, 1),
         {:ok, evidence} <-
           record_session_evidence(
             context,
             input,
             session_id,
             claim_id,
             action_name,
             "identity.application_session.created",
             result_payload
           ) do
      session_result(result_payload, token, evidence)
    end
  end

  defp rotate_transaction(context, input) do
    action_name = "identity.application_session.rotate_for_tenant"
    digest = token_digest(input.token)

    with {:ok, old_session_id} <- find_session_id(context.tenant_id, digest) do
      claim_rotation(context, input, digest, old_session_id, action_name)
    end
  end

  defp claim_rotation(context, input, digest, old_session_id, action_name) do
    new_session_id = UUID.generate()

    request_hash =
      request_hash(action_name, Map.put(input, :digest, digest) |> Map.delete(:token))

    with {:ok, claim} <-
           Evidence.claim(
             context,
             action_name,
             @aggregate,
             input.idempotency_key,
             request_hash,
             new_session_id
           ) do
      case claim do
        {:existing, stored} ->
          replay_session(stored, context, request_hash, input.idempotency_key)

        {:new, claim_id} ->
          rotate_session(
            context,
            input,
            digest,
            old_session_id,
            new_session_id,
            claim_id,
            action_name
          )
      end
    end
  end

  defp rotate_session(
         context,
         input,
         digest,
         old_session_id,
         new_session_id,
         claim_id,
         action_name
       ) do
    with {:ok, secret} <- session_secret(),
         {:ok, session} <- lock_session(context.tenant_id, digest),
         :ok <- ensure(session.id == old_session_id, :retryable_dependency),
         :ok <- validate_current_session(session, context),
         :ok <- validate_selected_membership(context, input.membership_id),
         token <- session_token(secret, context.tenant_id, input.idempotency_key, new_session_id),
         {:ok, times} <-
           insert_rotated_session(context, input, session, new_session_id, token_digest(token)),
         :ok <-
           mark_rotated(context.tenant_id, old_session_id, new_session_id, session.lock_version),
         result_payload <-
           rotated_payload(
             context,
             input,
             session,
             new_session_id,
             times,
             session.lock_version + 1
           ),
         {:ok, evidence} <-
           record_session_evidence(
             context,
             input,
             new_session_id,
             claim_id,
             action_name,
             "identity.application_session.rotated",
             result_payload
           ) do
      session_result(result_payload, token, evidence)
    end
  end

  defp end_session(runtime, context, input, status) do
    with {:ok, input} <- normalize_state(input) do
      write(runtime, context, &end_session_write(&1, input, status))
    end
  end

  defp end_session_write(context, input, status) do
    with :ok <- lock_writes(context.tenant_id) do
      end_session_transaction(context, input, status)
    end
  end

  defp end_session_transaction(context, input, status) do
    action_name = "identity.application_session.#{status}"
    digest = token_digest(input.token)

    with {:ok, session_id} <- find_session_id(context.tenant_id, digest) do
      claim_end_session(context, input, digest, session_id, status, action_name)
    end
  end

  defp claim_end_session(context, input, digest, session_id, status, action_name) do
    request_hash =
      request_hash(action_name, Map.put(input, :digest, digest) |> Map.delete(:token))

    with {:ok, claim} <-
           Evidence.claim(
             context,
             action_name,
             @aggregate,
             input.idempotency_key,
             request_hash,
             session_id
           ) do
      case claim do
        {:existing, stored} ->
          replay_state(stored, context.actor_id, request_hash, status)

        {:new, claim_id} ->
          finish_session(context, input, digest, status, claim_id, action_name)
      end
    end
  end

  defp finish_session(context, input, digest, status, claim_id, action_name) do
    with {:ok, session} <- lock_session(context.tenant_id, digest),
         :ok <- validate_current_session(session, context),
         :ok <- persist_end_state(context.tenant_id, session, status),
         result_payload <- %{
           "session_id" => session.id,
           "status" => Atom.to_string(status),
           "lock_version" => session.lock_version + 1
         },
         {:ok, _evidence} <-
           Evidence.record(context, %{
             action_name: action_name,
             aggregate_type: @aggregate,
             aggregate_id: session.id,
             idempotency_key: input.idempotency_key,
             causation_id: input.causation_id,
             before_version: session.lock_version,
             after_version: session.lock_version + 1,
             change_summary: %{"status" => Atom.to_string(status)},
             event_type: "identity.application_session.#{status}",
             event_payload: result_payload,
             result_payload: result_payload,
             claim_id: claim_id
           }) do
      {:ok, status}
    end
  end

  defp revoke_actor_transaction(context, idempotency_key, causation_id) do
    action_name = "identity.application_session.revoke_actor"
    request_hash = request_hash(action_name, %{causation_id: causation_id})

    with {:ok, claim} <-
           Evidence.claim(
             context,
             action_name,
             @aggregate,
             idempotency_key,
             request_hash,
             context.actor_id
           ) do
      case claim do
        {:existing, stored} ->
          replay_state(stored, context.actor_id, request_hash, :revoked)

        {:new, claim_id} ->
          revoke_actor_rows(context, idempotency_key, causation_id, claim_id, action_name)
      end
    end
  end

  defp revoke_actor_rows(context, idempotency_key, causation_id, claim_id, action_name) do
    case Repo.query(
           """
           UPDATE identity_application_sessions
           SET status = 'revoked', lock_version = lock_version + 1,
               updated_at = (NOW() AT TIME ZONE 'utc')
           WHERE tenant_id = $1 AND actor_id = $2 AND status = 'active'
           """,
           [dump(context.tenant_id), dump(context.actor_id)]
         ) do
      {:ok, %{num_rows: count}} ->
        result_payload = %{
          "session_id" => context.actor_id,
          "status" => "revoked",
          "lock_version" => 1,
          "revoked_count" => count
        }

        with {:ok, _evidence} <-
               Evidence.record(context, %{
                 action_name: action_name,
                 aggregate_type: @aggregate,
                 aggregate_id: context.actor_id,
                 idempotency_key: idempotency_key,
                 causation_id: causation_id,
                 before_version: 0,
                 after_version: 1,
                 change_summary: %{"revoked_count" => count},
                 event_type: "identity.application_session.actor_revoked",
                 event_payload: result_payload,
                 result_payload: result_payload,
                 claim_id: claim_id
               }) do
          {:ok, :revoked}
        end

      {:error, _error} ->
        error(:retryable_dependency)
    end
  end

  defp validate_create_references(context, input) do
    proof = input.proof

    case Repo.query(
           """
           SELECT membership.id::text
           FROM platform_tenant_memberships AS membership
           JOIN identity_external_identity_links AS link
             ON link.id = $4 AND link.actor_id = membership.actor_id AND link.status = 'active'
           JOIN identity_connections AS connection
             ON connection.id = link.connection_id AND connection.status = 'active'
           WHERE membership.tenant_id = $1 AND membership.id = $2 AND membership.actor_id = $3
             AND link.connection_id = $5 AND link.protocol = $6
             AND link.issuer = $7 AND link.subject = $8
           FOR KEY SHARE OF membership, link, connection
           """,
           [
             dump(context.tenant_id),
             dump(input.membership_id),
             dump(context.actor_id),
             dump(input.external_identity_link_id),
             dump(proof.connection_id),
             Atom.to_string(proof.protocol),
             proof.issuer,
             proof.subject
           ]
         ) do
      {:ok, %{rows: [[_membership_id]]}} -> :ok
      {:ok, %{rows: []}} -> error(:forbidden)
      {:error, _error} -> error(:retryable_dependency)
    end
  end

  defp insert_session(context, input, session_id, digest) do
    proof = input.proof

    case Repo.query(
           """
           INSERT INTO identity_application_sessions (
             id, tenant_id, actor_id, membership_id, external_identity_link_id,
             token_digest, status, assurance, assurance_at, idle_expires_at,
             absolute_expires_at, last_seen_at, lock_version, inserted_at, updated_at
           )
           VALUES ($1, $2, $3, $4, $5, $6, 'active', $7, $8,
                   (NOW() AT TIME ZONE 'utc') + INTERVAL '30 minutes',
                   (NOW() AT TIME ZONE 'utc') + INTERVAL '12 hours',
                   (NOW() AT TIME ZONE 'utc'), 1,
                   (NOW() AT TIME ZONE 'utc'), (NOW() AT TIME ZONE 'utc'))
           RETURNING idle_expires_at, absolute_expires_at
           """,
           [
             dump(session_id),
             dump(context.tenant_id),
             dump(context.actor_id),
             dump(input.membership_id),
             dump(input.external_identity_link_id),
             digest,
             proof.assurance,
             DateTime.to_naive(proof.authenticated_at)
           ]
         ) do
      {:ok, %{rows: [[idle, absolute]]}} -> {:ok, session_times(idle, absolute)}
      {:error, _error} -> error(:retryable_dependency)
    end
  end

  defp insert_rotated_session(context, input, session, session_id, digest) do
    case Repo.query(
           """
           INSERT INTO identity_application_sessions (
             id, tenant_id, actor_id, membership_id, external_identity_link_id,
             token_digest, status, assurance, assurance_at, idle_expires_at,
             absolute_expires_at, last_seen_at, lock_version, inserted_at, updated_at
           )
           VALUES ($1, $2, $3, $4, $5, $6, 'active', $7, $8,
                   LEAST((NOW() AT TIME ZONE 'utc') + INTERVAL '30 minutes', $9),
                   $9, (NOW() AT TIME ZONE 'utc'), 1,
                   (NOW() AT TIME ZONE 'utc'), (NOW() AT TIME ZONE 'utc'))
           RETURNING idle_expires_at, absolute_expires_at
           """,
           [
             dump(session_id),
             dump(context.tenant_id),
             dump(context.actor_id),
             dump(input.membership_id),
             dump(session.external_identity_link_id),
             digest,
             session.assurance,
             session.assurance_at,
             session.absolute_expires_at
           ]
         ) do
      {:ok, %{rows: [[idle, absolute]]}} -> {:ok, session_times(idle, absolute)}
      {:error, _error} -> error(:retryable_dependency)
    end
  end

  defp lock_session(tenant_id, digest) do
    case Repo.query(
           """
           SELECT session.id::text, session.actor_id::text, session.membership_id::text,
                  session.external_identity_link_id::text, session.status, session.assurance,
                  session.assurance_at, session.idle_expires_at, session.absolute_expires_at,
                  session.lock_version,
                  EXISTS (
                    SELECT 1 FROM platform_tenant_memberships AS membership
                    WHERE membership.tenant_id = session.tenant_id
                      AND membership.id = session.membership_id
                      AND membership.actor_id = session.actor_id
                  ) AS membership_current
           FROM identity_application_sessions AS session
           WHERE session.tenant_id = $1 AND session.token_digest = $2
           FOR UPDATE OF session
           """,
           [dump(tenant_id), digest]
         ) do
      {:ok,
       %{
         rows: [
           [
             id,
             actor_id,
             membership_id,
             link_id,
             status,
             assurance,
             assurance_at,
             idle,
             absolute,
             lock_version,
             membership_current
           ]
         ]
       }} ->
        {:ok,
         %{
           id: id,
           tenant_id: tenant_id,
           actor_id: actor_id,
           membership_id: membership_id,
           external_identity_link_id: link_id,
           status: status,
           assurance: assurance,
           assurance_at: assurance_at,
           idle_expires_at: idle,
           absolute_expires_at: absolute,
           lock_version: lock_version,
           membership_current: membership_current
         }}

      {:ok, %{rows: []}} ->
        error(:not_found)

      {:error, _error} ->
        error(:retryable_dependency)
    end
  end

  defp validate_current_session(session, context) do
    now = DateTime.utc_now() |> DateTime.to_naive()

    cond do
      session.status != "active" -> error(:forbidden)
      session.actor_id != context.actor_id -> error(:forbidden)
      session.membership_current != true -> error(:forbidden)
      NaiveDateTime.compare(session.idle_expires_at, now) != :gt -> error(:expired)
      NaiveDateTime.compare(session.absolute_expires_at, now) != :gt -> error(:expired)
      true -> :ok
    end
  end

  defp validate_selected_membership(context, membership_id) do
    case Repo.query(
           """
           SELECT id::text FROM platform_tenant_memberships
           WHERE tenant_id = $1 AND id = $2 AND actor_id = $3
           FOR KEY SHARE
           """,
           [dump(context.tenant_id), dump(membership_id), dump(context.actor_id)]
         ) do
      {:ok, %{rows: [[^membership_id]]}} -> :ok
      {:ok, %{rows: []}} -> error(:forbidden)
      {:error, _error} -> error(:retryable_dependency)
    end
  end

  defp refresh_idle(session) do
    case Repo.query(
           """
           UPDATE identity_application_sessions
           SET last_seen_at = (NOW() AT TIME ZONE 'utc'),
               idle_expires_at = LEAST(
                 (NOW() AT TIME ZONE 'utc') + INTERVAL '30 minutes',
                 absolute_expires_at
               ),
               lock_version = lock_version + 1,
               updated_at = (NOW() AT TIME ZONE 'utc')
           WHERE tenant_id = $1 AND id = $2 AND status = 'active' AND lock_version = $3
           RETURNING idle_expires_at, lock_version
           """,
           [dump(session.tenant_id), dump(session.id), session.lock_version]
         ) do
      {:ok, %{rows: [[idle, lock_version]]}} -> {:ok, utc(idle), lock_version}
      _failed -> error(:retryable_dependency)
    end
  end

  defp mark_rotated(tenant_id, old_session_id, new_session_id, version) do
    case Repo.query(
           """
           UPDATE identity_application_sessions
           SET status = 'rotated', rotated_to_session_id = $3,
               lock_version = lock_version + 1, updated_at = (NOW() AT TIME ZONE 'utc')
           WHERE tenant_id = $1 AND id = $2 AND status = 'active' AND lock_version = $4
           """,
           [dump(tenant_id), dump(old_session_id), dump(new_session_id), version]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      _failed -> error(:retryable_dependency)
    end
  end

  defp persist_end_state(tenant_id, session, status) do
    case Repo.query(
           """
           UPDATE identity_application_sessions
           SET status = $3, lock_version = lock_version + 1,
               updated_at = (NOW() AT TIME ZONE 'utc')
           WHERE tenant_id = $1 AND id = $2 AND status = 'active' AND lock_version = $4
           """,
           [dump(tenant_id), dump(session.id), Atom.to_string(status), session.lock_version]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      _failed -> error(:retryable_dependency)
    end
  end

  defp find_session_id(tenant_id, digest) do
    case Repo.query(
           "SELECT id::text FROM identity_application_sessions WHERE tenant_id = $1 AND token_digest = $2",
           [dump(tenant_id), digest]
         ) do
      {:ok, %{rows: [[id]]}} -> {:ok, id}
      {:ok, %{rows: []}} -> error(:not_found)
      {:error, _error} -> error(:retryable_dependency)
    end
  end

  defp record_session_evidence(context, input, session_id, claim_id, action, event, payload) do
    Evidence.record(context, %{
      action_name: action,
      aggregate_type: @aggregate,
      aggregate_id: session_id,
      idempotency_key: input.idempotency_key,
      causation_id: input.causation_id,
      before_version: 0,
      after_version: 1,
      change_summary: %{
        "membership_id" => input.membership_id,
        "status" => "active"
      },
      event_type: event,
      event_payload: Map.drop(payload, ["assurance", "assurance_at"]),
      result_payload: payload,
      claim_id: claim_id
    })
  end

  defp replay_session(stored, context, request_hash, idempotency_key) do
    with {:ok, secret} <- session_secret(),
         {:ok, claim} <- Evidence.replay(stored, context.actor_id, request_hash),
         {:ok, result} <- session_result_from_payload(claim.result_payload, claim),
         token <- session_token(secret, context.tenant_id, idempotency_key, result.id) do
      {:ok, %{result | token: token}}
    end
  end

  defp replay_state(stored, actor_id, request_hash, expected_status) do
    with {:ok, claim} <- Evidence.replay(stored, actor_id, request_hash),
         %{"status" => status} <- claim.result_payload,
         true <- status == Atom.to_string(expected_status) do
      {:ok, expected_status}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      _invalid -> error(:retryable_dependency)
    end
  end

  defp session_result(payload, token, evidence) do
    with {:ok, result} <-
           session_result_from_payload(payload, %{
             audit_reference: evidence.audit_reference,
             event_id: evidence.event_id
           }) do
      {:ok, %{result | token: token}}
    end
  end

  defp session_result_from_payload(payload, evidence) do
    with %{
           "session_id" => session_id,
           "tenant_id" => tenant_id,
           "actor_id" => actor_id,
           "membership_id" => membership_id,
           "assurance" => assurance,
           "assurance_at" => assurance_at,
           "idle_expires_at" => idle,
           "absolute_expires_at" => absolute,
           "lock_version" => lock_version
         } <- payload,
         {:ok, session_id} <- uuid(session_id),
         {:ok, tenant_id} <- uuid(tenant_id),
         {:ok, actor_id} <- uuid(actor_id),
         {:ok, membership_id} <- uuid(membership_id),
         {:ok, assurance_at, 0} <- DateTime.from_iso8601(assurance_at),
         {:ok, idle, 0} <- DateTime.from_iso8601(idle),
         {:ok, absolute, 0} <- DateTime.from_iso8601(absolute),
         {:ok, audit_reference} <- uuid(evidence.audit_reference),
         {:ok, event_id} <- uuid(evidence.event_id) do
      {:ok,
       %SessionResult{
         id: session_id,
         token: "",
         tenant_id: tenant_id,
         actor_id: actor_id,
         membership_id: membership_id,
         assurance: assurance,
         assurance_at: assurance_at,
         idle_expires_at: idle,
         absolute_expires_at: absolute,
         lock_version: lock_version,
         audit_reference: audit_reference,
         event_id: event_id
       }}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      _invalid -> error(:retryable_dependency)
    end
  end

  defp session_payload(context, input, session_id, times, lock_version) do
    %{
      "session_id" => session_id,
      "tenant_id" => context.tenant_id,
      "actor_id" => context.actor_id,
      "membership_id" => input.membership_id,
      "assurance" => input.proof.assurance,
      "assurance_at" => DateTime.to_iso8601(input.proof.authenticated_at),
      "idle_expires_at" => DateTime.to_iso8601(times.idle),
      "absolute_expires_at" => DateTime.to_iso8601(times.absolute),
      "lock_version" => lock_version
    }
  end

  defp rotated_payload(context, input, session, session_id, times, lock_version) do
    %{
      "session_id" => session_id,
      "tenant_id" => context.tenant_id,
      "actor_id" => context.actor_id,
      "membership_id" => input.membership_id,
      "assurance" => session.assurance,
      "assurance_at" => session.assurance_at |> utc() |> DateTime.to_iso8601(),
      "idle_expires_at" => DateTime.to_iso8601(times.idle),
      "absolute_expires_at" => DateTime.to_iso8601(times.absolute),
      "lock_version" => lock_version
    }
  end

  defp session_view(session, idle, lock_version) do
    %SessionView{
      id: session.id,
      tenant_id: session.tenant_id,
      actor_id: session.actor_id,
      membership_id: session.membership_id,
      assurance: session.assurance,
      assurance_at: utc(session.assurance_at),
      idle_expires_at: idle,
      absolute_expires_at: utc(session.absolute_expires_at),
      lock_version: lock_version
    }
  end

  defp session_times(idle, absolute), do: %{idle: utc(idle), absolute: utc(absolute)}
  defp utc(%NaiveDateTime{} = value), do: DateTime.from_naive!(value, "Etc/UTC")
  defp utc(%DateTime{} = value), do: value

  defp normalize_create(input) do
    with {:ok, input} <- exact_input(input, @create_keys),
         {:ok, link_id} <- uuid(input.external_identity_link_id),
         {:ok, membership_id} <- uuid(input.membership_id),
         true <- match?(%VerifiedExternalIdentity{}, input.proof),
         {:ok, idempotency_key} <- uuid(input.idempotency_key),
         {:ok, causation_id} <- uuid(input.causation_id) do
      {:ok,
       %{
         external_identity_link_id: link_id,
         membership_id: membership_id,
         proof: input.proof,
         idempotency_key: idempotency_key,
         causation_id: causation_id
       }}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      _invalid -> error(:invalid_input)
    end
  end

  defp normalize_rotate(input) do
    with {:ok, input} <- exact_input(input, @rotate_keys),
         {:ok, token} <- token(input.token),
         {:ok, membership_id} <- uuid(input.membership_id),
         {:ok, idempotency_key} <- uuid(input.idempotency_key),
         {:ok, causation_id} <- uuid(input.causation_id) do
      {:ok,
       %{
         token: token,
         membership_id: membership_id,
         idempotency_key: idempotency_key,
         causation_id: causation_id
       }}
    end
  end

  defp normalize_state(input) do
    with {:ok, input} <- exact_input(input, @state_keys),
         {:ok, token} <- token(input.token),
         {:ok, idempotency_key} <- uuid(input.idempotency_key),
         {:ok, causation_id} <- uuid(input.causation_id) do
      {:ok, %{token: token, idempotency_key: idempotency_key, causation_id: causation_id}}
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

  defp normalize_key(key, keys) when is_binary(key),
    do: Enum.find(keys, &(Atom.to_string(&1) == key))

  defp normalize_key(_key, _keys), do: nil

  defp token(value) when is_binary(value) do
    trimmed = String.trim(value)
    if String.length(trimmed) in 20..500, do: {:ok, trimmed}, else: error(:invalid_input)
  end

  defp token(_value), do: error(:invalid_input)

  defp uuid(value) do
    case UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> error(:invalid_input)
    end
  end

  defp fresh_assurance(authenticated_at) do
    now = DateTime.utc_now()

    if DateTime.compare(authenticated_at, DateTime.add(now, -10 * 60, :second)) in [:eq, :gt] and
         DateTime.compare(authenticated_at, DateTime.add(now, 60, :second)) in [:eq, :lt] do
      :ok
    else
      error(:forbidden)
    end
  end

  defp session_secret do
    case Application.get_env(:chimwemwe_core, :identity_session_hmac_secret) do
      secret when is_binary(secret) and byte_size(secret) >= 32 -> {:ok, secret}
      _missing_or_short -> error(:retryable_dependency)
    end
  end

  defp session_token(secret, tenant_id, idempotency_key, session_id) do
    :crypto.mac(:hmac, :sha256, secret, Enum.join([tenant_id, idempotency_key, session_id], ":"))
    |> Base.url_encode64(padding: false)
  end

  defp token_digest(token), do: :crypto.hash(:sha256, token)

  defp ensure(true, _code), do: :ok
  defp ensure(false, code), do: error(code)

  defp request_hash(action, input) do
    {action, input}
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
  end

  defp write(runtime, context, operation) do
    InternalWriter.run(runtime, context, operation)
  end

  defp lock_writes(tenant_id) do
    case Repo.query(
           "SELECT pg_advisory_xact_lock(hashtextextended('identity-session-writes:' || $1::text, 0))",
           [tenant_id]
         ) do
      {:ok, _result} -> :ok
      _failed -> error(:retryable_dependency)
    end
  end

  defp dump(value), do: UUID.dump!(value)
  defp error(code), do: {:error, %Error{code: code}}
end
