defmodule Chimwemwe.Identity.SupportFoundation do
  @moduledoc """
  Internal, non-impersonating support-access grant boundary.

  Every grant names one real support actor, tenant, purpose, ticket reference,
  and code-allowed capability set. Every activation and use is bound to the
  actor's current opaque session and five-minute assurance freshness.
  """

  alias Chimwemwe.Identity.{
    Error,
    Evidence,
    InternalWriter,
    SupportGrantResult,
    SupportSessionView,
    SupportUseResult
  }

  alias Chimwemwe.Platform.Authority
  alias Chimwemwe.Repo
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  @manage_capability "identity.support.grants.create"
  @aggregate "identity.support_access_grant"
  @allowed_capabilities MapSet.new([
                          "support.identity.connection.inspect",
                          "support.session.revoke",
                          "support.tenant.configuration.inspect"
                        ])
  @grant_keys [
    :capability_scope,
    :causation_id,
    :duration_minutes,
    :grantor_session_token,
    :idempotency_key,
    :purpose,
    :support_actor_id,
    :ticket_reference
  ]
  @activate_keys [:causation_id, :grant_id, :idempotency_key, :session_token]
  @use_keys [
    :capability,
    :causation_id,
    :grant_id,
    :idempotency_key,
    :mode,
    :purpose,
    :session_token
  ]
  @revoke_keys [
    :causation_id,
    :expected_version,
    :grant_id,
    :grantor_session_token,
    :idempotency_key
  ]
  @validate_keys [:grant_id, :purpose, :session_token]

  @doc "Approves one bounded support grant through an independently authenticated grantor."
  @spec grant(Supervisor.supervisor(), term(), map()) ::
          {:ok, SupportGrantResult.t()} | {:error, term()}
  def grant(runtime, context, input) do
    with {:ok, input} <- normalize_grant(input) do
      write(runtime, context, &grant_write(&1, input))
    end
  end

  @doc "Binds an approved grant to the real support actor's current strong session."
  def activate(runtime, context, input) do
    with {:ok, input} <- normalize_activate(input) do
      write(runtime, context, &activate_write(&1, input))
    end
  end

  @doc "Rechecks and records one interactive use of an allowed support capability."
  @spec use_grant(Supervisor.supervisor(), term(), map()) ::
          {:ok, SupportUseResult.t()} | {:error, term()}
  def use_grant(runtime, context, input) do
    with {:ok, input} <- normalize_use(input) do
      write(runtime, context, &use_write(&1, input))
    end
  end

  @doc "Rechecks the active grant bound to one current support session."
  @spec validate_active(Supervisor.supervisor(), term(), map()) ::
          {:ok, SupportSessionView.t()} | {:error, term()}
  def validate_active(runtime, context, input) do
    with {:ok, input} <- normalize_validate(input) do
      write(runtime, context, &validate_active_write(&1, input))
    end
  end

  @doc "Revokes an approved or active grant through a currently authorized grantor."
  def revoke(runtime, context, input) do
    with {:ok, input} <- normalize_revoke(input) do
      write(runtime, context, &revoke_write(&1, input))
    end
  end

  @doc "Ends the current support actor's active grant."
  def end_access(runtime, context, input) do
    with {:ok, input} <- normalize_activate(input) do
      write(runtime, context, &end_access_write(&1, input))
    end
  end

  @doc false
  def allowed_capabilities, do: MapSet.to_list(@allowed_capabilities) |> Enum.sort()

  defp grant_write(context, input) do
    with :ok <- lock_writes(context.tenant_id),
         :ok <- authorize(context.actor, @manage_capability),
         :ok <- ensure(input.support_actor_id != context.actor_id, :forbidden),
         {:ok, _session} <-
           validate_session(
             context,
             token_digest(input.grantor_session_token),
             context.actor_id
           ),
         :ok <- support_actor_membership(context.tenant_id, input.support_actor_id) do
      grant_transaction(context, input)
    end
  end

  defp activate_write(context, input) do
    with :ok <- lock_writes(context.tenant_id) do
      activate_transaction(context, input)
    end
  end

  defp use_write(context, input) do
    with :ok <- lock_writes(context.tenant_id) do
      use_transaction(context, input)
    end
  end

  defp validate_active_write(context, input) do
    with :ok <- lock_writes(context.tenant_id),
         {:ok, grant} <- lock_grant(context.tenant_id, input.grant_id),
         :ok <- ensure(grant.status == "active", :forbidden),
         :ok <- ensure(grant.support_actor_id == context.actor_id, :forbidden),
         :ok <- ensure(not_expired?(grant.expires_at), :expired),
         :ok <- ensure(grant.purpose == input.purpose, :forbidden),
         {:ok, session} <-
           validate_session(context, token_digest(input.session_token), context.actor_id),
         :ok <- ensure(session.id == grant.session_id, :forbidden) do
      {:ok,
       %SupportSessionView{
         grant_id: grant.id,
         support_actor_id: grant.support_actor_id,
         purpose: grant.purpose,
         expires_at: utc(grant.expires_at),
         capability_scope: grant.capability_scope
       }}
    end
  end

  defp revoke_write(context, input) do
    with :ok <- lock_writes(context.tenant_id),
         :ok <- authorize(context.actor, @manage_capability),
         {:ok, _session} <-
           validate_session(
             context,
             token_digest(input.grantor_session_token),
             context.actor_id
           ) do
      transition_transaction(context, input, :revoked)
    end
  end

  defp end_access_write(context, input) do
    with :ok <- lock_writes(context.tenant_id) do
      transition_transaction(context, input, :ended)
    end
  end

  defp grant_transaction(context, input) do
    action = "identity.support_access_grant.approve"
    grant_id = UUID.generate()
    request_hash = request_hash(action, Map.delete(input, :grantor_session_token))

    with {:ok, claim} <-
           Evidence.claim(
             context,
             action,
             @aggregate,
             input.idempotency_key,
             request_hash,
             grant_id
           ) do
      case claim do
        {:existing, stored} -> replay_grant(stored, context.actor_id, request_hash)
        {:new, claim_id} -> create_grant(context, input, grant_id, claim_id, action)
      end
    end
  end

  defp create_grant(context, input, grant_id, claim_id, action) do
    case Repo.query(
           """
           INSERT INTO identity_support_access_grants (
             id, tenant_id, support_actor_id, grantor_actor_id, purpose,
             ticket_reference, capability_scope, assurance_required, status,
             expires_at, lock_version, inserted_at, updated_at
           )
           VALUES ($1, $2, $3, $4, $5, $6, $7, 'mfa', 'approved',
                   (NOW() AT TIME ZONE 'utc') + make_interval(mins => $8::integer), 1,
                   (NOW() AT TIME ZONE 'utc'), (NOW() AT TIME ZONE 'utc'))
           RETURNING expires_at
           """,
           [
             dump(grant_id),
             dump(context.tenant_id),
             dump(input.support_actor_id),
             dump(context.actor_id),
             input.purpose,
             input.ticket_reference,
             input.capability_scope,
             input.duration_minutes
           ]
         ) do
      {:ok, %{rows: [[expires_at]]}} ->
        payload = grant_payload(grant_id, input, :approved, utc(expires_at), 1)

        with {:ok, evidence} <-
               record_grant(
                 context,
                 input,
                 grant_id,
                 claim_id,
                 %{
                   action: action,
                   event: "identity.support_access_grant.approved",
                   before_version: 0,
                   after_version: 1,
                   payload: payload
                 }
               ) do
          grant_result(payload, evidence)
        end

      {:error, error} ->
        translate_query_error(error)
    end
  end

  defp activate_transaction(context, input) do
    action = "identity.support_access_grant.activate"
    request_hash = request_hash(action, Map.delete(input, :session_token))

    with {:ok, claim} <-
           Evidence.claim(
             context,
             action,
             @aggregate,
             input.idempotency_key,
             request_hash,
             input.grant_id
           ) do
      case claim do
        {:existing, stored} -> replay_grant(stored, context.actor_id, request_hash)
        {:new, claim_id} -> activate_grant(context, input, claim_id, action)
      end
    end
  end

  defp activate_grant(context, input, claim_id, action) do
    with {:ok, grant} <- lock_grant(context.tenant_id, input.grant_id),
         :ok <- ensure(grant.status == "approved", :conflict),
         :ok <- ensure(grant.support_actor_id == context.actor_id, :forbidden),
         :ok <- ensure(not_expired?(grant.expires_at), :expired),
         {:ok, session} <-
           validate_session(context, token_digest(input.session_token), context.actor_id),
         :ok <- bind_grant(context.tenant_id, grant.id, session.id, grant.lock_version),
         payload <- grant_payload_from_record(grant, :active, grant.lock_version + 1),
         {:ok, evidence} <-
           record_grant(
             context,
             input,
             grant.id,
             claim_id,
             %{
               action: action,
               event: "identity.support_access_grant.activated",
               before_version: grant.lock_version,
               after_version: grant.lock_version + 1,
               payload: payload
             }
           ) do
      grant_result(payload, evidence)
    end
  end

  defp use_transaction(context, input) do
    action = "identity.support_access_grant.use"
    request_hash = request_hash(action, Map.delete(input, :session_token))

    with {:ok, claim} <-
           Evidence.claim(
             context,
             action,
             @aggregate,
             input.idempotency_key,
             request_hash,
             input.grant_id
           ) do
      case claim do
        {:existing, stored} -> replay_use(stored, context.actor_id, request_hash)
        {:new, claim_id} -> use_active_grant(context, input, claim_id, action)
      end
    end
  end

  defp use_active_grant(context, input, claim_id, action) do
    digest = token_digest(input.session_token)

    with {:ok, grant} <- lock_grant(context.tenant_id, input.grant_id),
         :ok <- ensure(grant.status == "active", :forbidden),
         :ok <- ensure(grant.support_actor_id == context.actor_id, :forbidden),
         :ok <- ensure(not_expired?(grant.expires_at), :expired),
         :ok <- ensure(grant.purpose == input.purpose, :forbidden),
         :ok <- ensure(input.capability in grant.capability_scope, :forbidden),
         :ok <- ensure(MapSet.member?(@allowed_capabilities, input.capability), :forbidden),
         {:ok, session} <- validate_session(context, digest, context.actor_id),
         :ok <- ensure(session.id == grant.session_id, :forbidden),
         :ok <- increment_use(context.tenant_id, grant.id, grant.lock_version),
         result_payload <- %{
           "grant_id" => grant.id,
           "support_actor_id" => context.actor_id,
           "capability" => input.capability,
           "purpose" => input.purpose,
           "lock_version" => grant.lock_version + 1
         },
         {:ok, evidence} <-
           Evidence.record(context, %{
             action_name: action,
             aggregate_type: @aggregate,
             aggregate_id: grant.id,
             idempotency_key: input.idempotency_key,
             causation_id: input.causation_id,
             before_version: grant.lock_version,
             after_version: grant.lock_version + 1,
             change_summary: %{"capability" => input.capability, "mode" => "interactive"},
             event_type: "identity.support_access_grant.used",
             event_payload: result_payload,
             result_payload: result_payload,
             claim_id: claim_id
           }) do
      {:ok,
       %SupportUseResult{
         grant_id: grant.id,
         support_actor_id: context.actor_id,
         capability: input.capability,
         purpose: input.purpose,
         audit_reference: evidence.audit_reference,
         event_id: evidence.event_id
       }}
    end
  end

  defp transition_transaction(context, input, next_status) do
    action = "identity.support_access_grant.#{next_status}"
    request_hash = request_hash(action, Map.drop(input, [:grantor_session_token, :session_token]))

    with {:ok, claim} <-
           Evidence.claim(
             context,
             action,
             @aggregate,
             input.idempotency_key,
             request_hash,
             input.grant_id
           ) do
      case claim do
        {:existing, stored} -> replay_grant(stored, context.actor_id, request_hash)
        {:new, claim_id} -> transition_grant(context, input, next_status, claim_id, action)
      end
    end
  end

  defp transition_grant(context, input, next_status, claim_id, action) do
    with {:ok, grant} <- lock_grant(context.tenant_id, input.grant_id),
         :ok <- transition_authorized?(grant, context, input, next_status),
         :ok <- persist_transition(context.tenant_id, grant, next_status),
         payload <- grant_payload_from_record(grant, next_status, grant.lock_version + 1),
         {:ok, evidence} <-
           record_grant(
             context,
             input,
             grant.id,
             claim_id,
             %{
               action: action,
               event: "identity.support_access_grant.#{next_status}",
               before_version: grant.lock_version,
               after_version: grant.lock_version + 1,
               payload: payload
             }
           ) do
      grant_result(payload, evidence)
    end
  end

  defp transition_authorized?(grant, _context, input, :revoked) do
    with :ok <- ensure(grant.lock_version == input.expected_version, :stale) do
      ensure(grant.status in ["approved", "active"], :conflict)
    end
  end

  defp transition_authorized?(grant, context, input, :ended) do
    with :ok <- ensure(grant.status == "active", :conflict),
         :ok <- ensure(grant.support_actor_id == context.actor_id, :forbidden),
         {:ok, session} <-
           validate_session(context, token_digest(input.session_token), context.actor_id) do
      ensure(session.id == grant.session_id, :forbidden)
    end
  end

  defp validate_session(context, digest, actor_id) do
    case Repo.query(
           """
           SELECT session.id::text, session.actor_id::text, session.assurance,
                  session.assurance_at, session.status,
                  session.idle_expires_at, session.absolute_expires_at,
                  EXISTS (
                    SELECT 1 FROM platform_tenant_memberships AS membership
                    WHERE membership.tenant_id = session.tenant_id
                      AND membership.id = session.membership_id
                      AND membership.actor_id = session.actor_id
                  ) AS membership_current
           FROM identity_application_sessions AS session
           WHERE session.tenant_id = $1 AND session.token_digest = $2
           FOR KEY SHARE OF session
           """,
           [dump(context.tenant_id), digest]
         ) do
      {:ok,
       %{
         rows: [
           [
             id,
             session_actor_id,
             assurance,
             assurance_at,
             status,
             idle,
             absolute,
             membership_current
           ]
         ]
       }} ->
        session = %{
          id: id,
          actor_id: session_actor_id,
          assurance: assurance,
          assurance_at: assurance_at,
          status: status,
          idle_expires_at: idle,
          absolute_expires_at: absolute,
          membership_current: membership_current
        }

        validate_support_session(session, actor_id)

      {:ok, %{rows: []}} ->
        error(:forbidden)

      {:error, _error} ->
        error(:retryable_dependency)
    end
  end

  defp validate_support_session(session, actor_id) do
    now = DateTime.utc_now() |> DateTime.to_naive()
    assurance_cutoff = DateTime.utc_now() |> DateTime.add(-5 * 60, :second) |> DateTime.to_naive()

    with :ok <- validate_support_session_owner(session, actor_id),
         :ok <- validate_support_assurance(session, assurance_cutoff, now),
         :ok <- validate_support_session_expiry(session, now),
         :ok <- ensure(session.membership_current == true, :forbidden) do
      {:ok, session}
    end
  end

  defp validate_support_session_owner(session, actor_id) do
    cond do
      session.actor_id != actor_id -> error(:forbidden)
      session.status != "active" -> error(:forbidden)
      session.assurance not in ["mfa", "strong"] -> error(:forbidden)
      true -> :ok
    end
  end

  defp validate_support_assurance(session, assurance_cutoff, now) do
    cond do
      NaiveDateTime.compare(session.assurance_at, assurance_cutoff) == :lt -> error(:forbidden)
      NaiveDateTime.compare(session.assurance_at, now) == :gt -> error(:forbidden)
      true -> :ok
    end
  end

  defp validate_support_session_expiry(session, now) do
    cond do
      NaiveDateTime.compare(session.idle_expires_at, now) != :gt -> error(:expired)
      NaiveDateTime.compare(session.absolute_expires_at, now) != :gt -> error(:expired)
      true -> :ok
    end
  end

  defp support_actor_membership(tenant_id, actor_id) do
    case Repo.query(
           "SELECT id FROM platform_tenant_memberships WHERE tenant_id = $1 AND actor_id = $2 FOR KEY SHARE",
           [dump(tenant_id), dump(actor_id)]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:ok, %{num_rows: 0}} -> error(:forbidden)
      {:error, _error} -> error(:retryable_dependency)
    end
  end

  defp lock_grant(tenant_id, grant_id) do
    case Repo.query(
           """
           SELECT id::text, support_actor_id::text, grantor_actor_id::text,
                  session_id::text, purpose, ticket_reference, capability_scope,
                  assurance_required, status, expires_at, lock_version
           FROM identity_support_access_grants
           WHERE tenant_id = $1 AND id = $2
           FOR UPDATE
           """,
           [dump(tenant_id), dump(grant_id)]
         ) do
      {:ok,
       %{
         rows: [
           [
             id,
             support_actor_id,
             grantor_actor_id,
             session_id,
             purpose,
             ticket,
             scope,
             assurance,
             status,
             expires_at,
             lock_version
           ]
         ]
       }} ->
        {:ok,
         %{
           id: id,
           support_actor_id: support_actor_id,
           grantor_actor_id: grantor_actor_id,
           session_id: session_id,
           purpose: purpose,
           ticket_reference: ticket,
           capability_scope: scope,
           assurance_required: assurance,
           status: status,
           expires_at: expires_at,
           lock_version: lock_version
         }}

      {:ok, %{rows: []}} ->
        error(:not_found)

      {:error, _error} ->
        error(:retryable_dependency)
    end
  end

  defp bind_grant(tenant_id, grant_id, session_id, version) do
    case Repo.query(
           """
           UPDATE identity_support_access_grants
           SET status = 'active', session_id = $3,
               activated_at = (NOW() AT TIME ZONE 'utc'),
               lock_version = lock_version + 1,
               updated_at = (NOW() AT TIME ZONE 'utc')
           WHERE tenant_id = $1 AND id = $2 AND status = 'approved' AND lock_version = $4
           """,
           [dump(tenant_id), dump(grant_id), dump(session_id), version]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      _failed -> error(:retryable_dependency)
    end
  end

  defp increment_use(tenant_id, grant_id, version) do
    case Repo.query(
           """
           UPDATE identity_support_access_grants
           SET lock_version = lock_version + 1, updated_at = (NOW() AT TIME ZONE 'utc')
           WHERE tenant_id = $1 AND id = $2 AND status = 'active' AND lock_version = $3
           """,
           [dump(tenant_id), dump(grant_id), version]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      _failed -> error(:retryable_dependency)
    end
  end

  defp persist_transition(tenant_id, grant, status) do
    case Repo.query(
           """
           UPDATE identity_support_access_grants
           SET status = $3, ended_at = (NOW() AT TIME ZONE 'utc'),
               lock_version = lock_version + 1,
               updated_at = (NOW() AT TIME ZONE 'utc')
           WHERE tenant_id = $1 AND id = $2 AND lock_version = $4
           """,
           [dump(tenant_id), dump(grant.id), Atom.to_string(status), grant.lock_version]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      _failed -> error(:retryable_dependency)
    end
  end

  defp record_grant(context, input, grant_id, claim_id, evidence_input) do
    payload = evidence_input.payload

    Evidence.record(context, %{
      action_name: evidence_input.action,
      aggregate_type: @aggregate,
      aggregate_id: grant_id,
      idempotency_key: input.idempotency_key,
      causation_id: input.causation_id,
      before_version: evidence_input.before_version,
      after_version: evidence_input.after_version,
      change_summary: %{
        "status" => payload["status"],
        "capability_scope" => payload["capability_scope"]
      },
      event_type: evidence_input.event,
      event_payload: Map.drop(payload, ["purpose"]),
      result_payload: payload,
      claim_id: claim_id
    })
  end

  defp replay_grant(stored, actor_id, request_hash) do
    with {:ok, claim} <- Evidence.replay(stored, actor_id, request_hash) do
      grant_result_from_payload(claim.result_payload, claim)
    end
  end

  defp replay_use(stored, actor_id, request_hash) do
    with {:ok, claim} <- Evidence.replay(stored, actor_id, request_hash),
         %{
           "grant_id" => grant_id,
           "support_actor_id" => support_actor_id,
           "capability" => capability,
           "purpose" => purpose
         } <- claim.result_payload,
         {:ok, grant_id} <- uuid(grant_id),
         {:ok, support_actor_id} <- uuid(support_actor_id),
         {:ok, audit_reference} <- uuid(claim.audit_reference),
         {:ok, event_id} <- uuid(claim.event_id) do
      {:ok,
       %SupportUseResult{
         grant_id: grant_id,
         support_actor_id: support_actor_id,
         capability: capability,
         purpose: purpose,
         audit_reference: audit_reference,
         event_id: event_id
       }}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      _invalid -> error(:retryable_dependency)
    end
  end

  defp grant_result(payload, evidence) do
    grant_result_from_payload(payload, %{
      audit_reference: evidence.audit_reference,
      event_id: evidence.event_id
    })
  end

  defp grant_result_from_payload(payload, evidence) do
    with %{
           "grant_id" => grant_id,
           "support_actor_id" => support_actor_id,
           "status" => status,
           "capability_scope" => scope,
           "purpose" => purpose,
           "expires_at" => expires_at,
           "lock_version" => lock_version
         } <- payload,
         {:ok, grant_id} <- uuid(grant_id),
         {:ok, support_actor_id} <- uuid(support_actor_id),
         {:ok, status} <- status(status),
         {:ok, expires_at, 0} <- DateTime.from_iso8601(expires_at),
         {:ok, audit_reference} <- uuid(evidence.audit_reference),
         {:ok, event_id} <- uuid(evidence.event_id) do
      {:ok,
       %SupportGrantResult{
         id: grant_id,
         support_actor_id: support_actor_id,
         status: status,
         capability_scope: scope,
         purpose: purpose,
         expires_at: expires_at,
         lock_version: lock_version,
         audit_reference: audit_reference,
         event_id: event_id
       }}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      _invalid -> error(:retryable_dependency)
    end
  end

  defp grant_payload(grant_id, input, status, expires_at, version) do
    %{
      "grant_id" => grant_id,
      "support_actor_id" => input.support_actor_id,
      "status" => Atom.to_string(status),
      "capability_scope" => input.capability_scope,
      "purpose" => input.purpose,
      "expires_at" => DateTime.to_iso8601(expires_at),
      "lock_version" => version
    }
  end

  defp grant_payload_from_record(grant, status, version) do
    %{
      "grant_id" => grant.id,
      "support_actor_id" => grant.support_actor_id,
      "status" => Atom.to_string(status),
      "capability_scope" => grant.capability_scope,
      "purpose" => grant.purpose,
      "expires_at" => grant.expires_at |> utc() |> DateTime.to_iso8601(),
      "lock_version" => version
    }
  end

  defp normalize_grant(input) do
    with {:ok, input} <- exact_input(input, @grant_keys),
         {:ok, support_actor_id} <- uuid(input.support_actor_id),
         {:ok, purpose} <- bounded(input.purpose, 3, 240),
         {:ok, ticket} <- bounded(input.ticket_reference, 3, 120),
         {:ok, scope} <- capability_scope(input.capability_scope),
         true <- is_integer(input.duration_minutes) and input.duration_minutes in 1..60,
         {:ok, session_token} <- token(input.grantor_session_token),
         {:ok, idempotency_key} <- uuid(input.idempotency_key),
         {:ok, causation_id} <- uuid(input.causation_id) do
      {:ok,
       %{
         support_actor_id: support_actor_id,
         purpose: purpose,
         ticket_reference: ticket,
         capability_scope: scope,
         duration_minutes: input.duration_minutes,
         grantor_session_token: session_token,
         idempotency_key: idempotency_key,
         causation_id: causation_id
       }}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      _invalid -> error(:invalid_input)
    end
  end

  defp normalize_activate(input) do
    with {:ok, input} <- exact_input(input, @activate_keys),
         {:ok, grant_id} <- uuid(input.grant_id),
         {:ok, session_token} <- token(input.session_token),
         {:ok, idempotency_key} <- uuid(input.idempotency_key),
         {:ok, causation_id} <- uuid(input.causation_id) do
      {:ok,
       %{
         grant_id: grant_id,
         session_token: session_token,
         idempotency_key: idempotency_key,
         causation_id: causation_id
       }}
    end
  end

  defp normalize_use(input) do
    with {:ok, input} <- exact_input(input, @use_keys),
         {:ok, grant_id} <- uuid(input.grant_id),
         {:ok, session_token} <- token(input.session_token),
         {:ok, capability} <- bounded(input.capability, 3, 120),
         true <- MapSet.member?(@allowed_capabilities, capability),
         {:ok, purpose} <- bounded(input.purpose, 3, 240),
         true <- input.mode == :interactive,
         {:ok, idempotency_key} <- uuid(input.idempotency_key),
         {:ok, causation_id} <- uuid(input.causation_id) do
      {:ok,
       %{
         grant_id: grant_id,
         session_token: session_token,
         capability: capability,
         purpose: purpose,
         mode: :interactive,
         idempotency_key: idempotency_key,
         causation_id: causation_id
       }}
    else
      {:error, %Error{} = identity_error} -> {:error, identity_error}
      _invalid -> error(:invalid_input)
    end
  end

  defp normalize_revoke(input) do
    with {:ok, input} <- exact_input(input, @revoke_keys),
         {:ok, grant_id} <- uuid(input.grant_id),
         true <- is_integer(input.expected_version) and input.expected_version > 0,
         {:ok, session_token} <- token(input.grantor_session_token),
         {:ok, idempotency_key} <- uuid(input.idempotency_key),
         {:ok, causation_id} <- uuid(input.causation_id) do
      {:ok,
       %{
         grant_id: grant_id,
         expected_version: input.expected_version,
         grantor_session_token: session_token,
         idempotency_key: idempotency_key,
         causation_id: causation_id
       }}
    end
  end

  defp normalize_validate(input) do
    with {:ok, input} <- exact_input(input, @validate_keys),
         {:ok, grant_id} <- uuid(input.grant_id),
         {:ok, purpose} <- bounded(input.purpose, 3, 240),
         {:ok, session_token} <- token(input.session_token) do
      {:ok, %{grant_id: grant_id, purpose: purpose, session_token: session_token}}
    end
  end

  defp capability_scope(value) when is_list(value) do
    normalized = Enum.uniq(value)

    if normalized != [] and length(normalized) <= 8 and
         Enum.all?(normalized, &MapSet.member?(@allowed_capabilities, &1)) do
      {:ok, Enum.sort(normalized)}
    else
      error(:invalid_input)
    end
  end

  defp capability_scope(_value), do: error(:invalid_input)

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

  defp bounded(value, minimum, maximum) when is_binary(value) do
    trimmed = String.trim(value)
    length = String.length(trimmed)
    if length in minimum..maximum, do: {:ok, trimmed}, else: error(:invalid_input)
  end

  defp bounded(_value, _minimum, _maximum), do: error(:invalid_input)
  defp token(value), do: bounded(value, 20, 500)

  defp uuid(value) do
    case UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> error(:invalid_input)
    end
  end

  defp status("approved"), do: {:ok, :approved}
  defp status("active"), do: {:ok, :active}
  defp status("revoked"), do: {:ok, :revoked}
  defp status("ended"), do: {:ok, :ended}
  defp status(_status), do: error(:retryable_dependency)

  defp not_expired?(expires_at) do
    NaiveDateTime.compare(expires_at, DateTime.utc_now() |> DateTime.to_naive()) == :gt
  end

  defp token_digest(token), do: :crypto.hash(:sha256, token)

  defp request_hash(action, input) do
    {action, input}
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
  end

  defp utc(%NaiveDateTime{} = value), do: DateTime.from_naive!(value, "Etc/UTC")

  defp write(runtime, context, operation) do
    InternalWriter.run(runtime, context, operation)
  end

  defp authorize(actor, capability) do
    if Authority.actor_has_capability?(actor, capability), do: :ok, else: error(:forbidden)
  end

  defp lock_writes(tenant_id) do
    case Repo.query(
           "SELECT pg_advisory_xact_lock(hashtextextended('identity-support-writes:' || $1::text, 0))",
           [tenant_id]
         ) do
      {:ok, _result} -> :ok
      _failed -> error(:retryable_dependency)
    end
  end

  defp ensure(true, _code), do: :ok
  defp ensure(false, code), do: error(code)

  defp translate_query_error(%PostgrexError{postgres: %{constraint: constraint}})
       when constraint in [
              :identity_support_access_grants_independent_approval,
              "identity_support_access_grants_independent_approval"
            ],
       do: error(:forbidden)

  defp translate_query_error(_error), do: error(:retryable_dependency)

  defp dump(value), do: UUID.dump!(value)
  defp error(code), do: {:error, %Error{code: code}}
end
