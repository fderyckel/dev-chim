defmodule Chimwemwe.InstitutionalStructure.Foundation do
  @moduledoc """
  CF-1 named writer boundary: register a root institution, assign its initial
  operator, publish, and read one exact identity. Synthetic private L1 only.
  Current tenant-defined capabilities and both module gates are checked before
  every operation and replay. Publication reruns the trusted evidence check.
  """
  alias Chimwemwe.InstitutionalStructure.{
    ActionResult,
    Error,
    Evidence,
    InstitutionView,
    InternalWriter,
    OperatorVerification,
    Runtime
  }

  alias Chimwemwe.OrganizationLegal.Foundation, as: LegalFoundation
  alias Chimwemwe.Platform.{ModuleLifecycle, ModuleLifecycleError}
  alias Chimwemwe.Platform.ModuleLifecycle.ReleaseManifest
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @module_key "institution.structure"
  @aggregate_type "institution.structure.unit"
  @base_keys [:causation_id, :idempotency_key]
  @identity_keys [:institutional_unit_id, :expected_version]
  @capabilities %{
    register: "institution.structure.institutions.register",
    assign: "institution.structure.operators.assign_initial",
    publish: "institution.structure.institutions.publish",
    read: "institution.structure.institutions.read"
  }
  @actions %{
    register: "institution.structure.institution.register",
    assign: "institution.structure.operator.assign_initial",
    publish: "institution.structure.institution.publish"
  }

  @spec release_manifest() :: ReleaseManifest.t()
  def release_manifest do
    legal = LegalFoundation.release_manifest() |> ReleaseManifest.declarations()

    {:ok, manifest} =
      ReleaseManifest.new(
        legal ++
          [
            %{
              key: @module_key,
              version: "1.0.0",
              owner: "Learning-institution operations",
              dependencies: ["organization.legal"]
            }
          ]
      )

    manifest
  end

  @spec register_institution(Runtime.t(), term(), map()) ::
          {:ok, ActionResult.t()} | {:error, term()}
  def register_institution(runtime, context, input),
    do: mutate(runtime, context, :register, input)

  @spec assign_initial_operator(Runtime.t(), term(), map()) ::
          {:ok, ActionResult.t()} | {:error, term()}
  def assign_initial_operator(runtime, context, input),
    do: mutate(runtime, context, :assign, input)

  @spec publish_institution(Runtime.t(), term(), map()) ::
          {:ok, ActionResult.t()} | {:error, term()}
  def publish_institution(runtime, context, input), do: mutate(runtime, context, :publish, input)

  @spec current_institution(Runtime.t(), term(), term()) ::
          {:ok, InstitutionView.t()} | {:error, term()}
  def current_institution(runtime, context, id) do
    with {:ok, persistence} <- Runtime.persistence(runtime),
         {:ok, id} <- uuid(id) do
      InternalWriter.run(persistence, context, &read_authorized(&1, &2, id))
    end
  end

  defp mutate(runtime, context, operation, input) do
    with {:ok, persistence} <- Runtime.persistence(runtime),
         {:ok, input} <- normalize(operation, input) do
      InternalWriter.run(
        persistence,
        context,
        &transition_authorized(runtime, &1, &2, operation, input)
      )
    end
  end

  defp transition(runtime, context, operation, input) do
    id = Map.get(input, :institutional_unit_id) || UUID.generate()
    action = Map.fetch!(@actions, operation)
    hash = :crypto.hash(:sha256, :erlang.term_to_binary({action, input}, [:deterministic]))

    with {:ok, claim} <-
           Evidence.claim(context, action, @aggregate_type, input.idempotency_key, hash, id) do
      resolve_claim(claim, runtime, context, operation, input, id, action, hash)
    end
  end

  defp read_authorized(action_context, validated_context, id) do
    with :ok <- authorize(validated_context, :read) do
      read_current(action_context.tenant_id, id)
    end
  end

  defp transition_authorized(runtime, context, validated_context, operation, input) do
    with :ok <- authorize(validated_context, operation) do
      transition(runtime, context, operation, input)
    end
  end

  defp resolve_claim(
         {:existing, stored},
         _runtime,
         context,
         _operation,
         _input,
         _id,
         _action,
         hash
       ),
       do: replay(stored, context.actor_id, hash)

  defp resolve_claim({:new, claim_id}, runtime, context, operation, input, id, action, _hash) do
    with {:ok, status, version} <- perform(runtime, context, operation, input, id),
         payload = %{
           "institutional_unit_id" => id,
           "status" => status,
           "lock_version" => version
         },
         {:ok, evidence} <-
           Evidence.record(context, %{
             action_name: action,
             aggregate_type: @aggregate_type,
             aggregate_id: id,
             idempotency_key: input.idempotency_key,
             causation_id: input.causation_id,
             before_version: version - 1,
             after_version: version,
             change_summary: %{"transition" => Atom.to_string(operation)},
             event_type: action <> ".completed",
             event_payload: payload,
             result_payload: payload,
             claim_id: claim_id
           }) do
      result(payload, evidence.audit_reference, evidence.event_id)
    end
  end

  defp perform(_runtime, context, :register, input, id) do
    with :ok <- valid_zone(input.time_zone),
         :ok <-
           write(
             """
             INSERT INTO institutional_units
               (id, tenant_id, display_name, classification, time_zone, status, lock_version, inserted_at)
             VALUES ($1, $2, $3, 'institution', $4, 'draft', 1, NOW())
             """,
             [dump(id), dump(context.tenant_id), input.display_name, input.time_zone]
           ) do
      {:ok, "draft", 1}
    end
  end

  defp perform(runtime, context, :assign, input, id) do
    with {:ok, unit} <- lock_unit(context.tenant_id, id),
         :ok <- ensure(unit.lock_version == input.expected_version, :stale),
         :ok <- ensure(unit.status == "draft" and unit.lock_version == 1, :conflict),
         :ok <-
           lock_legal_entity(context.tenant_id, input.legal_entity_id, input.legal_entity_version),
         {:ok, clock} <- clock(unit.time_zone),
         :ok <-
           ensure(Date.compare(input.effective_from, clock.local_date) != :lt, :invalid_input),
         {:ok, proof} <- verify(runtime, context, unit, input, clock),
         :ok <-
           write(
             """
             INSERT INTO institution_initial_operator_assignments
               (id, tenant_id, institutional_unit_id, legal_entity_id, legal_entity_version,
                evidence_reference, effective_from, verification, recorded_by_actor_id, inserted_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
             """,
             [
               dump(UUID.generate()),
               dump(context.tenant_id),
               dump(id),
               dump(input.legal_entity_id),
               input.legal_entity_version,
               dump(input.evidence_reference),
               input.effective_from,
               proof,
               dump(context.actor_id)
             ]
           ),
         :ok <- advance(context.tenant_id, id, 1, "draft") do
      {:ok, "draft", 2}
    end
  end

  defp perform(runtime, context, :publish, input, id) do
    with {:ok, unit} <- lock_unit(context.tenant_id, id),
         :ok <- ensure(unit.lock_version == input.expected_version, :stale),
         :ok <- ensure(unit.status == "draft" and unit.lock_version == 2, :conflict),
         {:ok, assignment} <- load_assignment(context.tenant_id, id),
         :ok <-
           lock_legal_entity(
             context.tenant_id,
             assignment.legal_entity_id,
             assignment.legal_entity_version
           ),
         {:ok, clock} <- clock(unit.time_zone),
         :ok <- ensure(assignment.effective_from == clock.local_date, :invalid_input),
         {:ok, proof} <- verify(runtime, context, unit, assignment, clock),
         :ok <-
           write(
             """
             INSERT INTO institution_publications
               (id, tenant_id, institutional_unit_id, operator_assignment_id,
                verification, recorded_by_actor_id, inserted_at)
             VALUES ($1, $2, $3, $4, $5, $6, NOW())
             """,
             [
               dump(UUID.generate()),
               dump(context.tenant_id),
               dump(id),
               dump(assignment.id),
               proof,
               dump(context.actor_id)
             ]
           ),
         :ok <- advance(context.tenant_id, id, 2, "published") do
      {:ok, "published", 3}
    end
  end

  defp verify(runtime, context, unit, assignment, clock) do
    OperatorVerification.check(runtime, %{
      tenant_id: context.tenant_id,
      institutional_unit_id: unit.id,
      institution_version: unit.lock_version,
      legal_entity_id: assignment.legal_entity_id,
      legal_entity_version: assignment.legal_entity_version,
      evidence_reference: assignment.evidence_reference,
      effective_from: assignment.effective_from,
      checked_at: clock.checked_at,
      local_date: clock.local_date
    })
  end

  defp lock_unit(tenant_id, id) do
    case Repo.query(
           """
           SELECT status, lock_version, time_zone FROM institutional_units
           WHERE tenant_id = $1 AND id = $2 FOR UPDATE
           """,
           [dump(tenant_id), dump(id)]
         ) do
      {:ok, %{rows: [[status, version, zone]]}} ->
        {:ok, %{id: id, status: status, lock_version: version, time_zone: zone}}

      {:ok, %{rows: []}} ->
        error(:not_found)

      _failed ->
        error(:retryable_dependency)
    end
  end

  defp lock_legal_entity(tenant_id, id, expected_version) do
    case Repo.query(
           """
           SELECT status, lock_version FROM organization_legal_entities
           WHERE tenant_id = $1 AND id = $2 FOR SHARE
           """,
           [dump(tenant_id), dump(id)]
         ) do
      {:ok, %{rows: [["active", ^expected_version]]}} -> :ok
      {:ok, %{rows: [[_status, _version]]}} -> error(:stale)
      {:ok, %{rows: []}} -> error(:not_found)
      _failed -> error(:retryable_dependency)
    end
  end

  defp load_assignment(tenant_id, id) do
    case Repo.query(
           """
           SELECT id::text, legal_entity_id::text, legal_entity_version, evidence_reference::text, effective_from
           FROM institution_initial_operator_assignments WHERE tenant_id = $1 AND institutional_unit_id = $2
           """,
           [dump(tenant_id), dump(id)]
         ) do
      {:ok, %{rows: [[assignment_id, entity, version, reference, from]]}} ->
        {:ok,
         %{
           id: assignment_id,
           legal_entity_id: entity,
           legal_entity_version: version,
           evidence_reference: reference,
           effective_from: from
         }}

      _failed ->
        error(:retryable_dependency)
    end
  end

  defp advance(tenant_id, id, version, status) do
    write(
      """
      UPDATE institutional_units SET lock_version = lock_version + 1, status = $4
      WHERE tenant_id = $1 AND id = $2 AND lock_version = $3
      """,
      [dump(tenant_id), dump(id), version, status]
    )
  end

  defp read_current(tenant_id, id) do
    case Repo.query(
           """
           SELECT u.id::text, u.display_name, u.time_zone, u.status, u.lock_version,
                  a.id::text, a.legal_entity_id::text, a.effective_from, p.id::text
           FROM institutional_units u
           LEFT JOIN institution_initial_operator_assignments a ON a.institutional_unit_id = u.id AND a.tenant_id = u.tenant_id
           LEFT JOIN institution_publications p ON p.institutional_unit_id = u.id AND p.tenant_id = u.tenant_id
           WHERE u.tenant_id = $1 AND u.id = $2
           """,
           [dump(tenant_id), dump(id)]
         ) do
      {:ok, %{rows: [[id, name, zone, status, version, assignment, entity, from, publication]]}} ->
        {:ok,
         %InstitutionView{
           id: id,
           display_name: name,
           time_zone: zone,
           classification: :institution,
           status: status_atom(status),
           lock_version: version,
           operator_assignment_id: assignment,
           legal_entity_id: entity,
           effective_from: from,
           publication_id: publication
         }}

      {:ok, %{rows: []}} ->
        error(:not_found)

      _failed ->
        error(:retryable_dependency)
    end
  end

  defp authorize(context, operation) do
    case ModuleLifecycle.authorize_current_transaction(
           release_manifest(),
           context,
           @module_key,
           Map.fetch!(@capabilities, operation)
         ) do
      :ok -> :ok
      {:error, %ModuleLifecycleError{code: :forbidden}} -> error(:forbidden)
      {:error, %ModuleLifecycleError{code: :retryable_dependency}} -> error(:retryable_dependency)
      {:error, %ModuleLifecycleError{}} -> error(:module_unavailable)
      _failed -> error(:retryable_dependency)
    end
  end

  defp replay(stored, actor_id, hash) do
    with {:ok, replay} <- Evidence.replay(stored, actor_id, hash) do
      result(replay.result_payload, replay.audit_reference, replay.event_id)
    end
  end

  defp result(
         %{"institutional_unit_id" => id, "status" => status, "lock_version" => version},
         audit,
         event
       )
       when status in ["draft", "published"] and version in 1..3 do
    with {:ok, id} <- uuid(id), {:ok, audit} <- uuid(audit), {:ok, event} <- uuid(event) do
      {:ok,
       %ActionResult{
         id: id,
         status: status_atom(status),
         lock_version: version,
         audit_reference: audit,
         event_id: event
       }}
    end
  end

  defp result(_payload, _audit, _event), do: error(:retryable_dependency)

  defp normalize(operation, input) when is_map(input) and not is_struct(input) do
    with :ok <- ensure(Enum.sort(Map.keys(input)) == Enum.sort(keys(operation)), :invalid_input),
         {:ok, key} <- uuid(input.idempotency_key),
         {:ok, causation} <- uuid(input.causation_id),
         {:ok, normalized} <- normalize_fields(operation, input) do
      {:ok, %{normalized | idempotency_key: key, causation_id: causation}}
    end
  end

  defp normalize(_operation, _input), do: error(:invalid_input)

  defp keys(:register), do: @base_keys ++ [:display_name, :time_zone]

  defp keys(:assign),
    do:
      @base_keys ++
        @identity_keys ++
        [:legal_entity_id, :legal_entity_version, :evidence_reference, :effective_from]

  defp keys(:publish), do: @base_keys ++ @identity_keys

  defp normalize_fields(:register, input) do
    with {:ok, name} <- text(input.display_name, 200),
         {:ok, zone} <- text(input.time_zone, 100) do
      {:ok, %{input | display_name: name, time_zone: zone}}
    end
  end

  defp normalize_fields(operation, input) do
    with {:ok, id} <- uuid(input.institutional_unit_id),
         :ok <- positive(input.expected_version) do
      normalize_operator(operation, %{input | institutional_unit_id: id})
    end
  end

  defp normalize_operator(:publish, input), do: {:ok, input}

  defp normalize_operator(:assign, input) do
    with {:ok, entity} <- uuid(input.legal_entity_id),
         {:ok, reference} <- uuid(input.evidence_reference),
         :ok <- positive(input.legal_entity_version),
         :ok <- ensure(match?(%Date{}, input.effective_from), :invalid_input) do
      {:ok, %{input | legal_entity_id: entity, evidence_reference: reference}}
    end
  end

  defp valid_zone(zone) do
    case Repo.query("SELECT 1 FROM pg_timezone_names WHERE name = $1", [zone]) do
      {:ok, %{rows: [[1]]}} -> :ok
      {:ok, _missing} -> error(:invalid_input)
      _failed -> error(:retryable_dependency)
    end
  end

  defp clock(zone) do
    case Repo.query("SELECT NOW(), (NOW() AT TIME ZONE $1)::date", [zone]) do
      {:ok, %{rows: [[%DateTime{} = now, %Date{} = date]]}} ->
        {:ok, %{checked_at: now, local_date: date}}

      _failed ->
        error(:retryable_dependency)
    end
  end

  defp write(sql, params) do
    case Repo.query(sql, params) do
      {:ok, %{num_rows: 1}} ->
        :ok

      {:error, %Postgrex.Error{postgres: %{code: code}}}
      when code in [:unique_violation, :check_violation, :foreign_key_violation] ->
        error(:conflict)

      _failed ->
        error(:retryable_dependency)
    end
  end

  defp text(value, limit) when is_binary(value) do
    value = String.trim(value)

    if String.valid?(value) and String.length(value) in 1..limit,
      do: {:ok, value},
      else: error(:invalid_input)
  end

  defp text(_value, _limit), do: error(:invalid_input)
  defp positive(value) when is_integer(value) and value > 0, do: :ok
  defp positive(_value), do: error(:invalid_input)

  defp uuid(value) do
    case UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      _invalid -> error(:invalid_input)
    end
  end

  defp status_atom("draft"), do: :draft
  defp status_atom("published"), do: :published
  defp ensure(true, _code), do: :ok
  defp ensure(false, code), do: error(code)
  defp dump(value), do: UUID.dump!(value)
  defp error(code), do: {:error, %Error{code: code}}
end
