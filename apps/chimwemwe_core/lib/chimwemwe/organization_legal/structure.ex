defmodule Chimwemwe.OrganizationLegal.Structure do
  @moduledoc """
  Bounded Slice 2.1-C legal-structure action and exact-read boundary.

  Direct relationship facts, the management-reporting parent, and corporate
  units stay separate. Slice 2.1-C2a adds append-only relationship ending and
  corporate-unit name revision. None creates transitive ownership, statutory
  consolidation, primary operation, authorization, or recursive enumeration.
  """

  alias Chimwemwe.OrganizationLegal.{
    ActionResult,
    ConsolidationParentageView,
    CorporateUnitView,
    Error,
    Evidence,
    Foundation,
    InternalWriter,
    LegalEntityRelationshipView
  }

  alias Chimwemwe.Platform.{ModuleLifecycle, ModuleLifecycleError}
  alias Chimwemwe.Repo
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  @module_key "organization.legal"
  @relationships_capability "organization.legal.relationships.manage"
  @corporate_units_capability "organization.legal.corporate_units.manage"
  @read_capability "organization.legal.entities.read"

  @relationship_action "organization.legal.relationship.establish"
  @relationship_end_action "organization.legal.relationship.end"
  @consolidation_action "organization.legal.consolidation_parent.set"
  @corporate_unit_action "organization.legal.corporate_unit.register"
  @corporate_unit_revise_action "organization.legal.corporate_unit.profile.revise"

  @relationship_aggregate "organization.legal.relationship"
  @consolidation_aggregate "organization.legal.consolidation_parentage"
  @corporate_unit_aggregate "organization.legal.corporate_unit"

  @relationship_keys [
    :basis_key,
    :causation_id,
    :effective_from,
    :evidence_reference,
    :idempotency_key,
    :interest_bps,
    :relationship_type,
    :source_legal_entity_id,
    :target_legal_entity_id
  ]
  @relationship_end_keys [
    :causation_id,
    :effective_until,
    :evidence_reference,
    :expected_version,
    :idempotency_key,
    :relationship_id
  ]
  @consolidation_keys [
    :causation_id,
    :child_legal_entity_id,
    :effective_from,
    :evidence_reference,
    :idempotency_key,
    :parent_legal_entity_id
  ]
  @corporate_unit_keys [
    :causation_id,
    :display_name,
    :idempotency_key,
    :legal_entity_id,
    :official_name,
    :parent_corporate_unit_id
  ]
  @corporate_unit_revise_keys [
    :causation_id,
    :corporate_unit_id,
    :display_name,
    :expected_version,
    :idempotency_key,
    :official_name
  ]

  @relationship_catalog %{
    equity_interest: %{basis_key: :registered_equity, interest?: true},
    governing_body_appointment: %{basis_key: :governing_instrument, interest?: false},
    statutory_control: %{basis_key: :statute, interest?: false},
    contractual_control: %{basis_key: :contract, interest?: false}
  }

  @doc "Establishes one direct legal-entity relationship from the closed ADR 0031 catalogue."
  @spec establish_legal_entity_relationship(Supervisor.supervisor(), term(), map()) ::
          {:ok, ActionResult.t()} | {:error, term()}
  def establish_legal_entity_relationship(runtime, context, input) do
    with {:ok, input} <- normalize_relationship_input(input) do
      InternalWriter.run(runtime, context, &establish_relationship_authorized(&1, &2, input))
    end
  end

  @doc "Ends one direct relationship at an exclusive date without rewriting its fact."
  @spec end_legal_entity_relationship(Supervisor.supervisor(), term(), map()) ::
          {:ok, ActionResult.t()} | {:error, term()}
  def end_legal_entity_relationship(runtime, context, input) do
    with {:ok, input} <- normalize_relationship_end_input(input) do
      InternalWriter.run(runtime, context, &end_relationship_authorized(&1, &2, input))
    end
  end

  @doc "Sets the first primary management-reporting parent for one legal entity."
  @spec set_primary_consolidation_parent(Supervisor.supervisor(), term(), map()) ::
          {:ok, ActionResult.t()} | {:error, term()}
  def set_primary_consolidation_parent(runtime, context, input) do
    with {:ok, input} <- normalize_consolidation_input(input) do
      InternalWriter.run(runtime, context, &set_consolidation_authorized(&1, &2, input))
    end
  end

  @doc "Registers one named corporate unit under an exact legal entity and optional parent unit."
  @spec register_corporate_unit(Supervisor.supervisor(), term(), map()) ::
          {:ok, ActionResult.t()} | {:error, term()}
  def register_corporate_unit(runtime, context, input) do
    with {:ok, input} <- normalize_corporate_unit_input(input) do
      InternalWriter.run(runtime, context, &register_corporate_unit_authorized(&1, &2, input))
    end
  end

  @doc "Appends the next immutable name profile for one active corporate unit."
  @spec revise_corporate_unit_profile(Supervisor.supervisor(), term(), map()) ::
          {:ok, ActionResult.t()} | {:error, term()}
  def revise_corporate_unit_profile(runtime, context, input) do
    with {:ok, input} <- normalize_corporate_unit_revise_input(input) do
      InternalWriter.run(runtime, context, &revise_corporate_unit_authorized(&1, &2, input))
    end
  end

  @doc "Returns one exact relationship without enumerating the relationship graph."
  @spec current_legal_entity_relationship(Supervisor.supervisor(), term(), term()) ::
          {:ok, LegalEntityRelationshipView.t()} | {:error, term()}
  def current_legal_entity_relationship(runtime, context, relationship_id) do
    with {:ok, relationship_id} <- cast_uuid(relationship_id) do
      InternalWriter.run(runtime, context, &read_relationship_authorized(&1, &2, relationship_id))
    end
  end

  @doc "Returns the exact management-reporting parentage for one child entity."
  @spec current_primary_consolidation_parent(Supervisor.supervisor(), term(), term()) ::
          {:ok, ConsolidationParentageView.t()} | {:error, term()}
  def current_primary_consolidation_parent(runtime, context, child_legal_entity_id) do
    with {:ok, child_legal_entity_id} <- cast_uuid(child_legal_entity_id) do
      InternalWriter.run(
        runtime,
        context,
        &read_consolidation_authorized(&1, &2, child_legal_entity_id)
      )
    end
  end

  @doc "Returns one exact corporate unit and current name profile."
  @spec current_corporate_unit(Supervisor.supervisor(), term(), term()) ::
          {:ok, CorporateUnitView.t()} | {:error, term()}
  def current_corporate_unit(runtime, context, corporate_unit_id) do
    with {:ok, corporate_unit_id} <- cast_uuid(corporate_unit_id) do
      InternalWriter.run(
        runtime,
        context,
        &read_corporate_unit_authorized(&1, &2, corporate_unit_id)
      )
    end
  end

  defp establish_relationship_authorized(action_context, validated_context, input) do
    with :ok <- authorize(validated_context, @relationships_capability) do
      establish_relationship_transaction(action_context, input)
    end
  end

  defp end_relationship_authorized(action_context, validated_context, input) do
    with :ok <- authorize(validated_context, @relationships_capability) do
      end_relationship_transaction(action_context, input)
    end
  end

  defp set_consolidation_authorized(action_context, validated_context, input) do
    with :ok <- authorize(validated_context, @relationships_capability) do
      set_consolidation_transaction(action_context, input)
    end
  end

  defp register_corporate_unit_authorized(action_context, validated_context, input) do
    with :ok <- authorize(validated_context, @corporate_units_capability) do
      register_corporate_unit_transaction(action_context, input)
    end
  end

  defp revise_corporate_unit_authorized(action_context, validated_context, input) do
    with :ok <- authorize(validated_context, @corporate_units_capability) do
      revise_corporate_unit_transaction(action_context, input)
    end
  end

  defp read_relationship_authorized(action_context, validated_context, relationship_id) do
    with :ok <- authorize(validated_context, @read_capability) do
      read_relationship(action_context.tenant_id, relationship_id)
    end
  end

  defp read_consolidation_authorized(action_context, validated_context, child_id) do
    with :ok <- authorize(validated_context, @read_capability) do
      read_consolidation(action_context.tenant_id, child_id)
    end
  end

  defp read_corporate_unit_authorized(action_context, validated_context, corporate_unit_id) do
    with :ok <- authorize(validated_context, @read_capability) do
      read_corporate_unit(action_context.tenant_id, corporate_unit_id)
    end
  end

  defp establish_relationship_transaction(context, input) do
    relationship_id = UUID.generate()
    request_hash = request_hash(@relationship_action, input)

    with {:ok, claim} <-
           Evidence.claim(
             context,
             @relationship_action,
             @relationship_aggregate,
             input.idempotency_key,
             request_hash,
             relationship_id
           ) do
      case claim do
        {:existing, stored} ->
          replay(stored, context.actor_id, request_hash, "relationship_id")

        {:new, claim_id} ->
          create_relationship(context, input, relationship_id, claim_id)
      end
    end
  end

  defp create_relationship(context, input, relationship_id, claim_id) do
    with :ok <-
           require_active_entities(
             context.tenant_id,
             input.source_legal_entity_id,
             input.target_legal_entity_id
           ),
         :ok <- insert_relationship(context.tenant_id, relationship_id, input),
         result_payload <- %{
           "relationship_id" => relationship_id,
           "relationship_type" => Atom.to_string(input.relationship_type),
           "source_legal_entity_id" => input.source_legal_entity_id,
           "status" => "active",
           "target_legal_entity_id" => input.target_legal_entity_id,
           "lock_version" => 1
         },
         {:ok, evidence} <-
           Evidence.record(context, %{
             action_name: @relationship_action,
             aggregate_type: @relationship_aggregate,
             aggregate_id: relationship_id,
             idempotency_key: input.idempotency_key,
             causation_id: input.causation_id,
             before_version: 0,
             after_version: 1,
             change_summary: %{"changed_fields" => ["relationship"]},
             event_type: "organization.legal.relationship.established",
             event_payload: result_payload,
             result_payload: result_payload,
             claim_id: claim_id
           }) do
      action_result(relationship_id, evidence)
    end
  end

  defp end_relationship_transaction(context, input) do
    request_hash = request_hash(@relationship_end_action, input)

    with {:ok, claim} <-
           Evidence.claim(
             context,
             @relationship_end_action,
             @relationship_aggregate,
             input.idempotency_key,
             request_hash,
             input.relationship_id
           ) do
      case claim do
        {:existing, stored} ->
          replay(
            stored,
            context.actor_id,
            request_hash,
            "relationship_id",
            :ended,
            input.expected_version + 1
          )

        {:new, claim_id} ->
          end_relationship(context, input, claim_id)
      end
    end
  end

  defp end_relationship(context, input, claim_id) do
    next_version = input.expected_version + 1

    with {:ok, current} <- lock_relationship(context.tenant_id, input.relationship_id),
         :ok <- ensure(current.status == :active, :conflict),
         :ok <- ensure(current.lock_version == input.expected_version, :stale),
         :ok <- ensure(Date.after?(input.effective_until, current.effective_from), :invalid_input),
         :ok <- insert_relationship_termination(context, input),
         result_payload <- %{
           "effective_until" => Date.to_iso8601(input.effective_until),
           "lock_version" => next_version,
           "relationship_id" => input.relationship_id,
           "status" => "ended"
         },
         {:ok, evidence} <-
           Evidence.record(context, %{
             action_name: @relationship_end_action,
             aggregate_type: @relationship_aggregate,
             aggregate_id: input.relationship_id,
             idempotency_key: input.idempotency_key,
             causation_id: input.causation_id,
             before_version: input.expected_version,
             after_version: next_version,
             change_summary: %{"changed_fields" => ["effective_until", "status"]},
             event_type: "organization.legal.relationship.ended",
             event_payload: result_payload,
             result_payload: result_payload,
             claim_id: claim_id
           }) do
      action_result(input.relationship_id, :ended, next_version, evidence)
    end
  end

  defp set_consolidation_transaction(context, input) do
    parentage_id = UUID.generate()
    request_hash = request_hash(@consolidation_action, input)

    with {:ok, claim} <-
           Evidence.claim(
             context,
             @consolidation_action,
             @consolidation_aggregate,
             input.idempotency_key,
             request_hash,
             parentage_id
           ) do
      case claim do
        {:existing, stored} ->
          replay(stored, context.actor_id, request_hash, "parentage_id")

        {:new, claim_id} ->
          create_consolidation_parentage(context, input, parentage_id, claim_id)
      end
    end
  end

  defp create_consolidation_parentage(context, input, parentage_id, claim_id) do
    with :ok <- lock_consolidation_graph(context.tenant_id),
         :ok <-
           require_active_entities(
             context.tenant_id,
             input.child_legal_entity_id,
             input.parent_legal_entity_id
           ),
         :ok <-
           reject_consolidation_cycle(
             context.tenant_id,
             input.child_legal_entity_id,
             input.parent_legal_entity_id
           ),
         :ok <- insert_consolidation(context.tenant_id, parentage_id, input),
         result_payload <- %{
           "child_legal_entity_id" => input.child_legal_entity_id,
           "lock_version" => 1,
           "parent_legal_entity_id" => input.parent_legal_entity_id,
           "parentage_id" => parentage_id,
           "reporting_basis" => "management_reporting",
           "status" => "active"
         },
         {:ok, evidence} <-
           Evidence.record(context, %{
             action_name: @consolidation_action,
             aggregate_type: @consolidation_aggregate,
             aggregate_id: parentage_id,
             idempotency_key: input.idempotency_key,
             causation_id: input.causation_id,
             before_version: 0,
             after_version: 1,
             change_summary: %{"changed_fields" => ["primary_management_reporting_parent"]},
             event_type: "organization.legal.consolidation_parent.set",
             event_payload: result_payload,
             result_payload: result_payload,
             claim_id: claim_id
           }) do
      action_result(parentage_id, evidence)
    end
  end

  defp register_corporate_unit_transaction(context, input) do
    corporate_unit_id = UUID.generate()
    request_hash = request_hash(@corporate_unit_action, input)

    with {:ok, claim} <-
           Evidence.claim(
             context,
             @corporate_unit_action,
             @corporate_unit_aggregate,
             input.idempotency_key,
             request_hash,
             corporate_unit_id
           ) do
      case claim do
        {:existing, stored} ->
          replay(stored, context.actor_id, request_hash, "corporate_unit_id")

        {:new, claim_id} ->
          create_corporate_unit(context, input, corporate_unit_id, claim_id)
      end
    end
  end

  defp create_corporate_unit(context, input, corporate_unit_id, claim_id) do
    with :ok <- require_active_entity(context.tenant_id, input.legal_entity_id),
         :ok <-
           require_corporate_parent(
             context.tenant_id,
             input.legal_entity_id,
             input.parent_corporate_unit_id
           ),
         :ok <- insert_corporate_unit(context.tenant_id, corporate_unit_id, input),
         :ok <- insert_corporate_unit_profile(context, corporate_unit_id, input),
         result_payload <- %{
           "corporate_unit_id" => corporate_unit_id,
           "legal_entity_id" => input.legal_entity_id,
           "lock_version" => 1,
           "parent_corporate_unit_id" => input.parent_corporate_unit_id,
           "status" => "active"
         },
         {:ok, evidence} <-
           Evidence.record(context, %{
             action_name: @corporate_unit_action,
             aggregate_type: @corporate_unit_aggregate,
             aggregate_id: corporate_unit_id,
             idempotency_key: input.idempotency_key,
             causation_id: input.causation_id,
             before_version: 0,
             after_version: 1,
             change_summary: %{"changed_fields" => ["display_name", "official_name", "parent"]},
             event_type: "organization.legal.corporate_unit.registered",
             event_payload: result_payload,
             result_payload: result_payload,
             claim_id: claim_id
           }) do
      action_result(corporate_unit_id, evidence)
    end
  end

  defp revise_corporate_unit_transaction(context, input) do
    request_hash = request_hash(@corporate_unit_revise_action, input)

    with {:ok, claim} <-
           Evidence.claim(
             context,
             @corporate_unit_revise_action,
             @corporate_unit_aggregate,
             input.idempotency_key,
             request_hash,
             input.corporate_unit_id
           ) do
      case claim do
        {:existing, stored} ->
          replay(
            stored,
            context.actor_id,
            request_hash,
            "corporate_unit_id",
            :active,
            input.expected_version + 1
          )

        {:new, claim_id} ->
          revise_corporate_unit(context, input, claim_id)
      end
    end
  end

  defp revise_corporate_unit(context, input, claim_id) do
    next_version = input.expected_version + 1

    with {:ok, current} <- lock_corporate_unit_profile(context.tenant_id, input.corporate_unit_id),
         :ok <- ensure(current.lock_version == input.expected_version, :stale),
         {:ok, changed_fields} <- corporate_unit_changed_fields(current, input),
         :ok <-
           insert_corporate_unit_profile(
             context,
             input.corporate_unit_id,
             input,
             next_version
           ),
         result_payload <- %{
           "corporate_unit_id" => input.corporate_unit_id,
           "lock_version" => next_version,
           "status" => "active"
         },
         {:ok, evidence} <-
           Evidence.record(context, %{
             action_name: @corporate_unit_revise_action,
             aggregate_type: @corporate_unit_aggregate,
             aggregate_id: input.corporate_unit_id,
             idempotency_key: input.idempotency_key,
             causation_id: input.causation_id,
             before_version: input.expected_version,
             after_version: next_version,
             change_summary: %{"changed_fields" => changed_fields},
             event_type: "organization.legal.corporate_unit.profile_revised",
             event_payload: result_payload,
             result_payload: result_payload,
             claim_id: claim_id
           }) do
      action_result(input.corporate_unit_id, :active, next_version, evidence)
    end
  end

  defp insert_relationship(tenant_id, relationship_id, input) do
    query_result(
      """
      INSERT INTO organization_legal_entity_relationships (
        id, tenant_id, source_legal_entity_id, target_legal_entity_id,
        relationship_type, basis_key, interest_bps, effective_from,
        evidence_reference, status, lock_version, inserted_at, updated_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'active', 1,
              (NOW() AT TIME ZONE 'utc'), (NOW() AT TIME ZONE 'utc'))
      """,
      [
        dump_uuid(relationship_id),
        dump_uuid(tenant_id),
        dump_uuid(input.source_legal_entity_id),
        dump_uuid(input.target_legal_entity_id),
        Atom.to_string(input.relationship_type),
        Atom.to_string(input.basis_key),
        input.interest_bps,
        input.effective_from,
        input.evidence_reference
      ]
    )
  end

  defp insert_relationship_termination(context, input) do
    query_result(
      """
      INSERT INTO organization_legal_entity_relationship_terminations (
        id, tenant_id, relationship_id, effective_until, evidence_reference,
        recorded_by_actor_id, recorded_at, inserted_at
      )
      VALUES ($1, $2, $3, $4, $5, $6,
              (NOW() AT TIME ZONE 'utc'), (NOW() AT TIME ZONE 'utc'))
      """,
      [
        dump_uuid(UUID.generate()),
        dump_uuid(context.tenant_id),
        dump_uuid(input.relationship_id),
        input.effective_until,
        input.evidence_reference,
        dump_uuid(context.actor_id)
      ]
    )
  end

  defp insert_consolidation(tenant_id, parentage_id, input) do
    query_result(
      """
      INSERT INTO organization_legal_entity_consolidation_parentages (
        id, tenant_id, child_legal_entity_id, parent_legal_entity_id,
        reporting_basis, effective_from, evidence_reference, status,
        lock_version, inserted_at, updated_at
      )
      VALUES ($1, $2, $3, $4, 'management_reporting', $5, $6, 'active', 1,
              (NOW() AT TIME ZONE 'utc'), (NOW() AT TIME ZONE 'utc'))
      """,
      [
        dump_uuid(parentage_id),
        dump_uuid(tenant_id),
        dump_uuid(input.child_legal_entity_id),
        dump_uuid(input.parent_legal_entity_id),
        input.effective_from,
        input.evidence_reference
      ]
    )
  end

  defp insert_corporate_unit(tenant_id, corporate_unit_id, input) do
    query_result(
      """
      INSERT INTO organization_legal_corporate_units (
        id, tenant_id, legal_entity_id, parent_corporate_unit_id,
        status, lock_version, inserted_at, updated_at
      )
      VALUES ($1, $2, $3, $4, 'active', 1,
              (NOW() AT TIME ZONE 'utc'), (NOW() AT TIME ZONE 'utc'))
      """,
      [
        dump_uuid(corporate_unit_id),
        dump_uuid(tenant_id),
        dump_uuid(input.legal_entity_id),
        dump_nullable_uuid(input.parent_corporate_unit_id)
      ]
    )
  end

  defp insert_corporate_unit_profile(context, corporate_unit_id, input, revision_number \\ 1) do
    query_result(
      """
      INSERT INTO organization_legal_corporate_unit_profile_revisions (
        id, tenant_id, corporate_unit_id, revision_number, official_name,
        display_name, recorded_by_actor_id, recorded_at, inserted_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7,
              (NOW() AT TIME ZONE 'utc'), (NOW() AT TIME ZONE 'utc'))
      """,
      [
        dump_uuid(UUID.generate()),
        dump_uuid(context.tenant_id),
        dump_uuid(corporate_unit_id),
        revision_number,
        input.official_name,
        input.display_name,
        dump_uuid(context.actor_id)
      ]
    )
  end

  defp require_active_entities(tenant_id, first_id, second_id) do
    case Repo.query(
           """
           SELECT count(*)
           FROM organization_legal_entities
           WHERE tenant_id = $1 AND status = 'active' AND id IN ($2, $3)
           """,
           [dump_uuid(tenant_id), dump_uuid(first_id), dump_uuid(second_id)]
         ) do
      {:ok, %{rows: [[2]]}} -> :ok
      {:ok, _missing} -> error(:not_found)
      {:error, _failed} -> error(:retryable_dependency)
    end
  end

  defp require_active_entity(tenant_id, legal_entity_id) do
    case Repo.query(
           """
           SELECT 1
           FROM organization_legal_entities
           WHERE tenant_id = $1 AND id = $2 AND status = 'active'
           """,
           [dump_uuid(tenant_id), dump_uuid(legal_entity_id)]
         ) do
      {:ok, %{rows: [[1]]}} -> :ok
      {:ok, %{rows: []}} -> error(:not_found)
      {:error, _failed} -> error(:retryable_dependency)
    end
  end

  defp require_corporate_parent(_tenant_id, _legal_entity_id, nil), do: :ok

  defp require_corporate_parent(tenant_id, legal_entity_id, parent_id) do
    case Repo.query(
           """
           SELECT 1
           FROM organization_legal_corporate_units
           WHERE tenant_id = $1 AND legal_entity_id = $2 AND id = $3 AND status = 'active'
           """,
           [dump_uuid(tenant_id), dump_uuid(legal_entity_id), dump_uuid(parent_id)]
         ) do
      {:ok, %{rows: [[1]]}} -> :ok
      {:ok, %{rows: []}} -> error(:not_found)
      {:error, _failed} -> error(:retryable_dependency)
    end
  end

  defp lock_relationship(tenant_id, relationship_id) do
    case Repo.query(
           """
           SELECT relationship.effective_from, termination.effective_until
           FROM organization_legal_entity_relationships AS relationship
           LEFT JOIN organization_legal_entity_relationship_terminations AS termination
             ON termination.tenant_id = relationship.tenant_id
            AND termination.relationship_id = relationship.id
           WHERE relationship.tenant_id = $1 AND relationship.id = $2
           FOR UPDATE OF relationship
           """,
           [dump_uuid(tenant_id), dump_uuid(relationship_id)]
         ) do
      {:ok, %{rows: [[effective_from, nil]]}} ->
        {:ok, %{effective_from: effective_from, lock_version: 1, status: :active}}

      {:ok, %{rows: [[effective_from, effective_until]]}} ->
        {:ok,
         %{
           effective_from: effective_from,
           effective_until: effective_until,
           lock_version: 2,
           status: :ended
         }}

      {:ok, %{rows: []}} ->
        error(:not_found)

      _failed_or_inconsistent ->
        error(:retryable_dependency)
    end
  end

  defp lock_corporate_unit_profile(tenant_id, corporate_unit_id) do
    case Repo.query(
           """
           SELECT profile.revision_number, profile.official_name, profile.display_name
           FROM organization_legal_corporate_units AS unit
           JOIN LATERAL (
             SELECT revision_number, official_name, display_name
             FROM organization_legal_corporate_unit_profile_revisions
             WHERE tenant_id = unit.tenant_id AND corporate_unit_id = unit.id
             ORDER BY revision_number DESC
             LIMIT 1
           ) AS profile ON TRUE
           WHERE unit.tenant_id = $1 AND unit.id = $2 AND unit.status = 'active'
           FOR UPDATE OF unit
           """,
           [dump_uuid(tenant_id), dump_uuid(corporate_unit_id)]
         ) do
      {:ok, %{rows: [[version, official_name, display_name]]}} ->
        {:ok,
         %{
           lock_version: version,
           official_name: official_name,
           display_name: display_name
         }}

      {:ok, %{rows: []}} ->
        error(:not_found)

      _failed_or_inconsistent ->
        error(:retryable_dependency)
    end
  end

  defp lock_consolidation_graph(tenant_id) do
    case Repo.query(
           """
           SELECT pg_advisory_xact_lock(
             hashtextextended('organization-legal-consolidation:' || $1::text, 0)
           )
           """,
           [tenant_id]
         ) do
      {:ok, _result} -> :ok
      {:error, _failed} -> error(:retryable_dependency)
    end
  end

  defp reject_consolidation_cycle(tenant_id, child_id, parent_id) do
    case Repo.query(
           """
           WITH RECURSIVE ancestors(entity_id) AS (
             SELECT $3::uuid
             UNION ALL
             SELECT parentage.parent_legal_entity_id
             FROM organization_legal_entity_consolidation_parentages AS parentage
             JOIN ancestors ON ancestors.entity_id = parentage.child_legal_entity_id
             WHERE parentage.tenant_id = $1
           )
           SELECT EXISTS(SELECT 1 FROM ancestors WHERE entity_id = $2)
           """,
           [dump_uuid(tenant_id), dump_uuid(child_id), dump_uuid(parent_id)]
         ) do
      {:ok, %{rows: [[false]]}} -> :ok
      {:ok, %{rows: [[true]]}} -> error(:conflict)
      {:error, _failed} -> error(:retryable_dependency)
    end
  end

  defp read_relationship(tenant_id, relationship_id) do
    case Repo.query(
           """
           SELECT relationship.id::text, relationship.source_legal_entity_id::text,
                  relationship.target_legal_entity_id::text, relationship.relationship_type,
                  relationship.basis_key, relationship.interest_bps,
                  relationship.effective_from, termination.effective_until,
                  CASE WHEN termination.id IS NULL THEN 'active' ELSE 'ended' END,
                  CASE WHEN termination.id IS NULL THEN 1 ELSE 2 END
           FROM organization_legal_entity_relationships AS relationship
           LEFT JOIN organization_legal_entity_relationship_terminations AS termination
             ON termination.tenant_id = relationship.tenant_id
            AND termination.relationship_id = relationship.id
           WHERE relationship.tenant_id = $1 AND relationship.id = $2
           """,
           [dump_uuid(tenant_id), dump_uuid(relationship_id)]
         ) do
      {:ok,
       %{
         rows: [
           [
             id,
             source_id,
             target_id,
             type,
             basis,
             interest,
             effective_from,
             effective_until,
             status,
             version
           ]
         ]
       }}
      when status in ["active", "ended"] ->
        with {:ok, relationship_type} <- catalog_atom(type, Map.keys(@relationship_catalog)),
             {:ok, basis_key} <- basis_atom(relationship_type, basis) do
          {:ok,
           %LegalEntityRelationshipView{
             id: id,
             source_legal_entity_id: source_id,
             target_legal_entity_id: target_id,
             relationship_type: relationship_type,
             basis_key: basis_key,
             interest_bps: interest,
             effective_from: effective_from,
             effective_until: effective_until,
             status: String.to_existing_atom(status),
             lock_version: version
           }}
        end

      {:ok, %{rows: []}} ->
        error(:not_found)

      _failed_or_inconsistent ->
        error(:retryable_dependency)
    end
  end

  defp read_consolidation(tenant_id, child_id) do
    case Repo.query(
           """
           SELECT id::text, child_legal_entity_id::text, parent_legal_entity_id::text,
                  reporting_basis, effective_from, status, lock_version
           FROM organization_legal_entity_consolidation_parentages
           WHERE tenant_id = $1 AND child_legal_entity_id = $2
           """,
           [dump_uuid(tenant_id), dump_uuid(child_id)]
         ) do
      {:ok, %{rows: [[id, child, parent, "management_reporting", date, "active", version]]}} ->
        {:ok,
         %ConsolidationParentageView{
           id: id,
           child_legal_entity_id: child,
           parent_legal_entity_id: parent,
           reporting_basis: :management_reporting,
           effective_from: date,
           status: :active,
           lock_version: version
         }}

      {:ok, %{rows: []}} ->
        error(:not_found)

      _failed_or_inconsistent ->
        error(:retryable_dependency)
    end
  end

  defp read_corporate_unit(tenant_id, corporate_unit_id) do
    case Repo.query(
           """
           SELECT unit.id::text, unit.legal_entity_id::text,
                  unit.parent_corporate_unit_id::text, profile.official_name,
                  profile.display_name, unit.status, profile.revision_number,
                  profile.recorded_at
           FROM organization_legal_corporate_units AS unit
           JOIN LATERAL (
             SELECT revision_number, official_name, display_name, recorded_at
             FROM organization_legal_corporate_unit_profile_revisions
             WHERE tenant_id = unit.tenant_id AND corporate_unit_id = unit.id
             ORDER BY revision_number DESC
             LIMIT 1
           ) AS profile ON TRUE
           WHERE unit.tenant_id = $1 AND unit.id = $2
           """,
           [dump_uuid(tenant_id), dump_uuid(corporate_unit_id)]
         ) do
      {:ok, %{rows: [[id, entity_id, parent_id, official, display, "active", version, recorded]]}} ->
        {:ok,
         %CorporateUnitView{
           id: id,
           legal_entity_id: entity_id,
           parent_corporate_unit_id: parent_id,
           official_name: official,
           display_name: display,
           status: :active,
           lock_version: version,
           recorded_at: utc_datetime(recorded)
         }}

      {:ok, %{rows: []}} ->
        error(:not_found)

      _failed_or_inconsistent ->
        error(:retryable_dependency)
    end
  end

  defp normalize_relationship_input(input) do
    with {:ok, normalized} <- normalize_keys(input, @relationship_keys),
         {:ok, source_id} <- cast_uuid(normalized.source_legal_entity_id),
         {:ok, target_id} <- cast_uuid(normalized.target_legal_entity_id),
         true <- source_id != target_id,
         {:ok, relationship_type} <-
           catalog_atom(normalized.relationship_type, Map.keys(@relationship_catalog)),
         {:ok, basis_key} <- basis_atom(relationship_type, normalized.basis_key),
         {:ok, interest_bps} <- normalize_interest(relationship_type, normalized.interest_bps),
         {:ok, effective_from} <- normalized_date(normalized.effective_from),
         {:ok, evidence_reference} <- normalized_evidence_reference(normalized.evidence_reference),
         {:ok, idempotency_key} <- cast_uuid(normalized.idempotency_key),
         {:ok, causation_id} <- cast_uuid(normalized.causation_id) do
      {:ok,
       %{
         source_legal_entity_id: source_id,
         target_legal_entity_id: target_id,
         relationship_type: relationship_type,
         basis_key: basis_key,
         interest_bps: interest_bps,
         effective_from: effective_from,
         evidence_reference: evidence_reference,
         idempotency_key: idempotency_key,
         causation_id: causation_id
       }}
    else
      false -> error(:invalid_input)
      {:error, %Error{}} = error -> error
    end
  end

  defp normalize_relationship_end_input(input) do
    with {:ok, normalized} <- normalize_keys(input, @relationship_end_keys),
         {:ok, relationship_id} <- cast_uuid(normalized.relationship_id),
         {:ok, expected_version} <- normalized_version(normalized.expected_version),
         {:ok, effective_until} <- normalized_date(normalized.effective_until),
         {:ok, evidence_reference} <- normalized_evidence_reference(normalized.evidence_reference),
         {:ok, idempotency_key} <- cast_uuid(normalized.idempotency_key),
         {:ok, causation_id} <- cast_uuid(normalized.causation_id) do
      {:ok,
       %{
         relationship_id: relationship_id,
         expected_version: expected_version,
         effective_until: effective_until,
         evidence_reference: evidence_reference,
         idempotency_key: idempotency_key,
         causation_id: causation_id
       }}
    end
  end

  defp normalize_consolidation_input(input) do
    with {:ok, normalized} <- normalize_keys(input, @consolidation_keys),
         {:ok, child_id} <- cast_uuid(normalized.child_legal_entity_id),
         {:ok, parent_id} <- cast_uuid(normalized.parent_legal_entity_id),
         true <- child_id != parent_id,
         {:ok, effective_from} <- normalized_date(normalized.effective_from),
         {:ok, evidence_reference} <- normalized_evidence_reference(normalized.evidence_reference),
         {:ok, idempotency_key} <- cast_uuid(normalized.idempotency_key),
         {:ok, causation_id} <- cast_uuid(normalized.causation_id) do
      {:ok,
       %{
         child_legal_entity_id: child_id,
         parent_legal_entity_id: parent_id,
         effective_from: effective_from,
         evidence_reference: evidence_reference,
         idempotency_key: idempotency_key,
         causation_id: causation_id
       }}
    else
      false -> error(:invalid_input)
      {:error, %Error{}} = error -> error
    end
  end

  defp normalize_corporate_unit_input(input) do
    with {:ok, normalized} <- normalize_keys(input, @corporate_unit_keys),
         {:ok, legal_entity_id} <- cast_uuid(normalized.legal_entity_id),
         {:ok, parent_id} <- cast_nullable_uuid(normalized.parent_corporate_unit_id),
         {:ok, official_name} <- normalized_name(normalized.official_name),
         {:ok, display_name} <- normalized_name(normalized.display_name),
         {:ok, idempotency_key} <- cast_uuid(normalized.idempotency_key),
         {:ok, causation_id} <- cast_uuid(normalized.causation_id) do
      {:ok,
       %{
         legal_entity_id: legal_entity_id,
         parent_corporate_unit_id: parent_id,
         official_name: official_name,
         display_name: display_name,
         idempotency_key: idempotency_key,
         causation_id: causation_id
       }}
    end
  end

  defp normalize_corporate_unit_revise_input(input) do
    with {:ok, normalized} <- normalize_keys(input, @corporate_unit_revise_keys),
         {:ok, corporate_unit_id} <- cast_uuid(normalized.corporate_unit_id),
         {:ok, expected_version} <- normalized_version(normalized.expected_version),
         {:ok, official_name} <- normalized_name(normalized.official_name),
         {:ok, display_name} <- normalized_name(normalized.display_name),
         {:ok, idempotency_key} <- cast_uuid(normalized.idempotency_key),
         {:ok, causation_id} <- cast_uuid(normalized.causation_id) do
      {:ok,
       %{
         corporate_unit_id: corporate_unit_id,
         expected_version: expected_version,
         official_name: official_name,
         display_name: display_name,
         idempotency_key: idempotency_key,
         causation_id: causation_id
       }}
    end
  end

  defp normalize_interest(:equity_interest, value)
       when is_integer(value) and value in 1..10_000,
       do: {:ok, value}

  defp normalize_interest(type, nil) when type != :equity_interest, do: {:ok, nil}
  defp normalize_interest(_type, _value), do: error(:invalid_input)

  defp basis_atom(relationship_type, value) do
    expected = @relationship_catalog[relationship_type].basis_key

    case catalog_atom(value, [expected]) do
      {:ok, ^expected} -> {:ok, expected}
      _invalid -> error(:invalid_input)
    end
  end

  defp catalog_atom(value, allowed) when is_atom(value) do
    if value in allowed, do: {:ok, value}, else: error(:invalid_input)
  end

  defp catalog_atom(value, allowed) when is_binary(value) do
    case Enum.find(allowed, &(Atom.to_string(&1) == value)) do
      nil -> error(:invalid_input)
      atom -> {:ok, atom}
    end
  end

  defp catalog_atom(_value, _allowed), do: error(:invalid_input)

  defp normalized_date(%Date{} = value), do: {:ok, value}

  defp normalized_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      {:error, _reason} -> error(:invalid_input)
    end
  end

  defp normalized_date(_value), do: error(:invalid_input)

  defp normalized_version(value) when is_integer(value) and value >= 1, do: {:ok, value}
  defp normalized_version(_value), do: error(:invalid_input)

  defp normalized_evidence_reference(value) when is_binary(value) do
    normalized = String.trim(value)

    if String.length(normalized) in 1..120 and
         Regex.match?(~r/^[A-Za-z0-9][A-Za-z0-9._:\/-]*$/, normalized) do
      {:ok, normalized}
    else
      error(:invalid_input)
    end
  end

  defp normalized_evidence_reference(_value), do: error(:invalid_input)

  defp normalized_name(value) when is_binary(value) do
    normalized = String.trim(value)

    if String.length(normalized) in 1..200 do
      {:ok, normalized}
    else
      error(:invalid_input)
    end
  end

  defp normalized_name(_value), do: error(:invalid_input)

  defp corporate_unit_changed_fields(current, input) do
    changed_fields =
      []
      |> maybe_changed("official_name", current.official_name, input.official_name)
      |> maybe_changed("display_name", current.display_name, input.display_name)
      |> Enum.reverse()

    if changed_fields == [], do: error(:invalid_input), else: {:ok, changed_fields}
  end

  defp maybe_changed(fields, _field, value, value), do: fields
  defp maybe_changed(fields, field, _old_value, _new_value), do: [field | fields]

  defp normalize_keys(input, expected_keys) when is_map(input) and not is_struct(input) do
    normalized =
      Enum.reduce_while(input, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
        case normalize_key(key, expected_keys) do
          {:ok, normalized_key} when not is_map_key(acc, normalized_key) ->
            {:cont, {:ok, Map.put(acc, normalized_key, value)}}

          _invalid_or_duplicate ->
            {:halt, error(:invalid_input)}
        end
      end)

    with {:ok, values} <- normalized,
         true <- Enum.sort(Map.keys(values)) == Enum.sort(expected_keys) do
      {:ok, values}
    else
      _invalid -> error(:invalid_input)
    end
  end

  defp normalize_keys(_input, _expected_keys), do: error(:invalid_input)

  defp normalize_key(key, expected_keys) when is_atom(key) do
    if key in expected_keys, do: {:ok, key}, else: :error
  end

  defp normalize_key(key, expected_keys) when is_binary(key) do
    case Enum.find(expected_keys, &(Atom.to_string(&1) == key)) do
      nil -> :error
      normalized -> {:ok, normalized}
    end
  end

  defp normalize_key(_key, _expected_keys), do: :error

  defp replay(stored, actor_id, request_hash, result_id_key) do
    replay(stored, actor_id, request_hash, result_id_key, :active, 1)
  end

  defp replay(stored, actor_id, request_hash, result_id_key, expected_status, expected_version) do
    with {:ok, replay} <- Evidence.replay(stored, actor_id, request_hash),
         id when is_binary(id) <- replay.result_payload[result_id_key],
         {:ok, id} <- cast_uuid(id),
         ^expected_version <- replay.result_payload["lock_version"],
         status when is_binary(status) <- replay.result_payload["status"],
         ^expected_status <- result_status(status),
         {:ok, audit_reference} <- cast_uuid(replay.audit_reference),
         {:ok, event_id} <- cast_uuid(replay.event_id) do
      {:ok,
       %ActionResult{
         id: id,
         status: expected_status,
         lock_version: expected_version,
         audit_reference: audit_reference,
         event_id: event_id
       }}
    else
      {:error, %Error{}} = error -> error
      _invalid_stored_result -> error(:retryable_dependency)
    end
  end

  defp action_result(id, evidence) do
    action_result(id, :active, 1, evidence)
  end

  defp action_result(id, status, lock_version, evidence) do
    {:ok,
     %ActionResult{
       id: id,
       status: status,
       lock_version: lock_version,
       audit_reference: evidence.audit_reference,
       event_id: evidence.event_id
     }}
  end

  defp result_status("active"), do: :active
  defp result_status("ended"), do: :ended
  defp result_status(_status), do: :invalid

  defp query_result(sql, params) do
    case Repo.query(sql, params) do
      {:ok, %{num_rows: 1}} -> :ok
      {:error, error} -> translate_query_error(error)
      _unexpected -> error(:retryable_dependency)
    end
  end

  defp authorize(context, capability) do
    case ModuleLifecycle.authorize_current_transaction(
           Foundation.release_manifest(),
           context,
           @module_key,
           capability
         ) do
      :ok -> :ok
      {:error, %ModuleLifecycleError{code: :forbidden}} -> error(:forbidden)
      {:error, %ModuleLifecycleError{code: :retryable_dependency}} -> error(:retryable_dependency)
      {:error, %ModuleLifecycleError{code: :invalid_input}} -> error(:invalid_input)
      {:error, %ModuleLifecycleError{}} -> error(:module_unavailable)
      _unexpected -> error(:retryable_dependency)
    end
  end

  defp request_hash(action_name, input) do
    {action_name, input}
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
  end

  defp translate_query_error(%PostgrexError{postgres: %{code: :unique_violation}}),
    do: error(:conflict)

  defp translate_query_error(%PostgrexError{postgres: %{code: :foreign_key_violation}}),
    do: error(:not_found)

  defp translate_query_error(%PostgrexError{postgres: %{code: :check_violation}}),
    do: error(:invalid_input)

  defp translate_query_error(_error), do: error(:retryable_dependency)

  defp cast_uuid(value) do
    case UUID.cast(value) do
      {:ok, uuid} -> {:ok, uuid}
      :error -> error(:invalid_input)
    end
  end

  defp cast_nullable_uuid(nil), do: {:ok, nil}
  defp cast_nullable_uuid(value), do: cast_uuid(value)
  defp dump_nullable_uuid(nil), do: nil
  defp dump_nullable_uuid(value), do: dump_uuid(value)

  defp ensure(true, _code), do: :ok
  defp ensure(false, code), do: error(code)

  defp utc_datetime(%DateTime{} = value), do: value
  defp utc_datetime(%NaiveDateTime{} = value), do: DateTime.from_naive!(value, "Etc/UTC")

  defp dump_uuid(value), do: UUID.dump!(value)
  defp error(code), do: {:error, %Error{code: code}}
end
