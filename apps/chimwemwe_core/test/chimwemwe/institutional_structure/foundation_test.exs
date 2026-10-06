defmodule Chimwemwe.InstitutionalStructure.FoundationTest do
  use ExUnit.Case, async: false
  alias Chimwemwe.InstitutionalStructure.{Error, Foundation, Runtime, TestVerifier}
  alias Chimwemwe.OrganizationLegal.Foundation, as: LegalFoundation

  alias Chimwemwe.Platform.{
    ExecutionContext,
    Persistence,
    PersistenceRuntime,
    ResourceContract,
    TrustedActor,
    TrustedPlacement
  }

  alias Chimwemwe.Repo
  alias Ecto.UUID
  @tenant_a "41414141-4141-4141-8141-414141414141"
  @tenant_b "42424242-4242-4242-8242-424242424242"
  @actor_a "a1a1a1a1-a1a1-41a1-81a1-a1a1a1a1a1a1"
  @actor_a_peer "a2a2a2a2-a2a2-42a2-82a2-a2a2a2a2a2a2"
  @actor_a_denied "a3a3a3a3-a3a3-43a3-83a3-a3a3a3a3a3a3"
  @actor_b "b1b1b1b1-b1b1-41b1-81b1-b1b1b1b1b1b1"
  @manage_capability "institution.structure.institutions.register"
  @read_capability "institution.structure.institutions.read"
  @assign_capability "institution.structure.operators.assign_initial"
  @publish_capability "institution.structure.institutions.publish"

  setup do
    persistence = start_supervised!({PersistenceRuntime, runtime_options()})
    clear_fixture(persistence)
    ids = seed_foundation(persistence)
    source = start_supervised!({Agent, fn -> %{records: %{}, overrides: %{}, calls: 0} end})
    {:ok, runtime} = Runtime.new(persistence, TestVerifier, source)
    {:ok, Map.merge(ids, %{persistence: persistence, runtime: runtime, source: source})}
  end

  test "resources are tenant-owned and have no direct Ash actions" do
    assert :ok = ResourceContract.validate_domain(Chimwemwe.InstitutionalStructure)

    for resource <- Ash.Domain.Info.resources(Chimwemwe.InstitutionalStructure) do
      assert Ash.Resource.Info.actions(resource) == []
    end

    assert {:error, :invalid_runtime} = Runtime.new(self(), String, nil)
  end

  test "register, initial assignment, fresh publication, minimal exact read and replay", f do
    input = register_input()
    assert {:ok, unit} = Foundation.register_institution(f.runtime, context_a(), input)
    assert {:ok, ^unit} = Foundation.register_institution(f.runtime, context_a(), input)
    assert {:ok, view} = Foundation.current_institution(f.runtime, context_a(), unit.id)
    assert view.status == :draft and view.operator_assignment_id == nil
    assignment = assignment_input(f, unit)

    assert {:ok, assigned} =
             Foundation.assign_initial_operator(f.runtime, context_a(), assignment)

    assert assigned.lock_version == 2

    assert {:ok, ^assigned} =
             Foundation.assign_initial_operator(f.runtime, context_a(), assignment)

    publication = publish_input(unit.id)
    assert {:ok, published} = Foundation.publish_institution(f.runtime, context_a(), publication)
    assert published.status == :published and published.lock_version == 3
    assert {:ok, ^published} = Foundation.publish_institution(f.runtime, context_a(), publication)
    assert Agent.get(f.source, & &1.calls) == 2
    assert {:ok, view} = Foundation.current_institution(f.runtime, context_a(), unit.id)
    assert view.publication_id != nil and view.legal_entity_id == assignment.legal_entity_id
    refute Map.has_key?(view, :verification)
    assert [[3, 3, 3]] = facts(f)

    assert {:ok, %{rows: [[payload]]}} =
             query(f, "SELECT payload FROM platform_outbox_events WHERE id = $1", [
               dump(published.event_id)
             ])

    assert Map.keys(payload) |> Enum.sort() == ["institutional_unit_id", "lock_version", "status"]
  end

  test "context, capability and input fail closed", f do
    assert {:error, _} = Foundation.register_institution(f.runtime, nil, register_input())

    assert {:error, %Error{code: :forbidden}} =
             Foundation.register_institution(f.runtime, context_a_denied(), register_input())

    for extra <- [
          %{tenant_id: @tenant_b},
          %{verified: true},
          %{verifier: TestVerifier},
          %{parent_id: UUID.generate()}
        ] do
      assert {:error, %Error{code: :invalid_input}} =
               Foundation.register_institution(
                 f.runtime,
                 context_a(),
                 Map.merge(register_input(), extra)
               )
    end

    assert {:error, %Error{code: :invalid_input}} =
             Foundation.register_institution(f.runtime, context_a(), %{
               register_input()
               | time_zone: "Unknown/Zone"
             })

    assert [[0, 0, 0]] = facts(f)
  end

  test "cross-tenant and unknown reads have the same non-disclosing result", f do
    unit = register!(f)

    assert {:error, %Error{code: :not_found}} =
             Foundation.current_institution(f.runtime, context_b(), unit.id)

    assert {:error, %Error{code: :not_found}} =
             Foundation.current_institution(f.runtime, context_b(), UUID.generate())

    assert {:error, %Error{code: :forbidden}} =
             Foundation.current_institution(f.runtime, context_a_denied(), unit.id)

    assignment = assignment_input(f, unit, context_b())

    assert {:error, %Error{code: :not_found}} =
             Foundation.assign_initial_operator(f.runtime, context_a(), assignment)

    assert [[1, 1, 1]] = facts(f)
  end

  test "exact replay is actor/request bound and rechecks current permission", f do
    input = register_input()
    assert {:ok, _} = Foundation.register_institution(f.runtime, context_a(), input)

    assert {:error, %Error{code: :idempotency_conflict}} =
             Foundation.register_institution(f.runtime, context_a_peer(), input)

    assert {:error, %Error{code: :idempotency_conflict}} =
             Foundation.register_institution(f.runtime, context_a(), %{
               input
               | display_name: "Changed"
             })

    query(
      f,
      "DELETE FROM platform_actor_role_assignments WHERE tenant_id = $1 AND membership_id = $2",
      [dump(@tenant_a), dump(f.membership_a)]
    )

    assert {:error, %Error{code: :forbidden}} =
             Foundation.register_institution(f.runtime, context_a(), input)
  end

  test "disabled institution and legal dependency independently block operations", f do
    unit = register!(f)

    for key <- ["institution.structure", "organization.legal"] do
      assert {:ok, _} =
               query(
                 f,
                 "UPDATE platform_module_activations a SET state = 'inactive', replay_from_cursor = consumer_cursor, projection_ready = false, reconciliation_required = true, deactivated_at = NOW() FROM platform_module_entitlements e WHERE a.entitlement_id = e.id AND e.tenant_id = $1 AND e.module_key = $2",
                 [dump(@tenant_a), key]
               )

      assert {:error, %Error{code: :module_unavailable}} =
               Foundation.current_institution(f.runtime, context_a(), unit.id)

      query(
        f,
        "UPDATE platform_module_activations a SET state = 'active', replay_from_cursor = NULL, projection_ready = true, reconciliation_required = false FROM platform_module_entitlements e WHERE a.entitlement_id = e.id AND e.tenant_id = $1 AND e.module_key = $2",
        [dump(@tenant_a), key]
      )
    end
  end

  test "only one initial assignment and no publication without it", f do
    unit = register!(f)

    assert {:error, %Error{code: :conflict}} =
             Foundation.publish_institution(f.runtime, context_a(), %{
               publish_input(unit.id)
               | expected_version: 1
             })

    assignment = assignment_input(f, unit)
    assert {:ok, _} = Foundation.assign_initial_operator(f.runtime, context_a(), assignment)

    assert {:error, %Error{code: :stale}} =
             Foundation.assign_initial_operator(f.runtime, context_a(), %{
               assignment
               | idempotency_key: UUID.generate()
             })

    assert {:error, %Error{code: :conflict}} =
             Foundation.assign_initial_operator(f.runtime, context_a(), %{
               assignment
               | idempotency_key: UUID.generate(),
                 expected_version: 2
             })
  end

  test "publication checks source again and rejects revoked or inaccessible evidence", f do
    unit = register!(f)
    assignment = assignment_input(f, unit)
    assert {:ok, _} = Foundation.assign_initial_operator(f.runtime, context_a(), assignment)
    Agent.update(f.source, &Map.put(&1, :overrides, :revoked))

    assert {:error, %Error{code: :evidence_unavailable}} =
             Foundation.publish_institution(f.runtime, context_a(), publish_input(unit.id))

    assert {:ok, %{status: :draft, lock_version: 2}} =
             Foundation.current_institution(f.runtime, context_a(), unit.id)

    assert [[2, 2, 2]] = facts(f)
  end

  test "missing, stale, wrong-scope, unknown-policy and unaccepted impact proofs are refused",
       f do
    unit = register!(f)
    assignment = assignment_input(f, unit)

    invalid = [
      %{status_checked_on: Date.add(Date.utc_today(), -31)},
      %{status_checked_on: Date.add(Date.utc_today(), 1)},
      %{tenant_id: @tenant_b},
      %{institutional_unit_id: UUID.generate()},
      %{legal_entity_id: UUID.generate()},
      %{institution_version: 9},
      %{policy_key: "unknown"},
      %{jurisdiction: "unknown"},
      %{evidence_type: "incorporation_only"},
      %{valid_until: Date.utc_today()},
      %{conditions_satisfied: false},
      %{impact_accepted: false},
      %{consumer_keys: ["unreviewed"]},
      %{checked_at: DateTime.add(DateTime.utc_now(), -60)},
      %{document_url: "forbidden"}
    ]

    for override <- invalid do
      Agent.update(f.source, &Map.put(&1, :overrides, override))

      assert {:error, %Error{code: :evidence_unavailable}} =
               Foundation.assign_initial_operator(f.runtime, context_a(), assignment)
    end

    Agent.update(f.source, &%{&1 | overrides: %{}, records: %{}})

    assert {:error, %Error{code: :evidence_unavailable}} =
             Foundation.assign_initial_operator(f.runtime, context_a(), assignment)

    assert [[1, 1, 1]] = facts(f)
  end

  test "legal version and local effective date are revalidated", f do
    unit = register!(f)
    assignment = assignment_input(f, unit)

    assert {:error, %Error{code: :stale}} =
             Foundation.assign_initial_operator(f.runtime, context_a(), %{
               assignment
               | legal_entity_version: 2
             })

    assert {:error, %Error{code: :invalid_input}} =
             Foundation.assign_initial_operator(f.runtime, context_a(), %{
               assignment
               | effective_from: Date.add(Date.utc_today(), -1)
             })

    future = %{assignment | effective_from: Date.add(Date.utc_today(), 1)}
    assert {:ok, _} = Foundation.assign_initial_operator(f.runtime, context_a(), future)

    assert {:error, %Error{code: :invalid_input}} =
             Foundation.publish_institution(f.runtime, context_a(), publish_input(unit.id))
  end

  test "concurrent exact registration and competing assignment are serialized", f do
    input = register_input()

    results =
      Task.async_stream(
        1..4,
        fn _ -> Foundation.register_institution(f.runtime, context_a(), input) end,
        max_concurrency: 4
      )
      |> Enum.map(fn {:ok, value} -> value end)

    assert [{:ok, unit}] = Enum.uniq(results)
    assignment = assignment_input(f, unit)

    results =
      Task.async_stream(1..2, fn _ ->
        Foundation.assign_initial_operator(f.runtime, context_a(), %{
          assignment
          | idempotency_key: UUID.generate()
        })
      end)
      |> Enum.map(fn {:ok, value} -> value end)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &match?({:error, %Error{code: :stale}}, &1)) == 1
    assert [[2, 2, 2]] = facts(f)
  end

  test "failure completing idempotency rolls back state, audit and outbox", f do
    unit = register!(f)
    assignment = assignment_input(f, unit)
    assert {:ok, _} = Foundation.assign_initial_operator(f.runtime, context_a(), assignment)
    install_completion_failure(f.persistence)

    try do
      assert {:error, %Error{code: :retryable_dependency}} =
               Foundation.register_institution(f.runtime, context_a(), register_input())

      assert {:error, %Error{code: :retryable_dependency}} =
               Foundation.publish_institution(f.runtime, context_a(), publish_input(unit.id))

      assert {:ok, %{status: :draft, lock_version: 2}} =
               Foundation.current_institution(f.runtime, context_a(), unit.id)

      assert [[2, 2, 2]] = facts(f)
    after
      remove_completion_failure(f.persistence)
    end
  end

  test "database refuses changed identity, publication bypass and fact deletion", f do
    unit = register!(f)

    assert {:error, %Postgrex.Error{}} =
             query(f, "UPDATE institutional_units SET tenant_id = $2 WHERE id = $1", [
               dump(unit.id),
               dump(@tenant_b)
             ])

    assert {:error, %Postgrex.Error{}} =
             query(
               f,
               "UPDATE institutional_units SET status = 'published', lock_version = 3 WHERE id = $1",
               [dump(unit.id)]
             )

    assignment = assignment_input(f, unit)
    assert {:ok, _} = Foundation.assign_initial_operator(f.runtime, context_a(), assignment)

    assert {:error, %Postgrex.Error{}} =
             query(
               f,
               "DELETE FROM institution_initial_operator_assignments WHERE institutional_unit_id = $1",
               [dump(unit.id)]
             )

    assert {:ok, _} =
             Foundation.publish_institution(f.runtime, context_a(), publish_input(unit.id))

    assert {:error, %Postgrex.Error{}} =
             query(
               f,
               "UPDATE institutional_units SET status = 'draft', lock_version = 2 WHERE id = $1",
               [dump(unit.id)]
             )
  end

  test "publication rechecks the legal entity version and its own capability", f do
    unit = register!(f)
    assignment = assignment_input(f, unit)
    assert {:ok, _} = Foundation.assign_initial_operator(f.runtime, context_a(), assignment)

    assert {:ok, _} =
             query(f, "UPDATE organization_legal_entities SET lock_version = 2 WHERE id = $1", [
               dump(assignment.legal_entity_id)
             ])

    assert {:error, %Error{code: :stale}} =
             Foundation.publish_institution(f.runtime, context_a(), publish_input(unit.id))

    assert {:ok, _} =
             query(
               f,
               "DELETE FROM platform_role_capability_grants WHERE tenant_id = $1 AND capability_id = $2",
               [dump(@tenant_a), dump(f.publish_capability_a)]
             )

    assert {:error, %Error{code: :forbidden}} =
             Foundation.publish_institution(f.runtime, context_a(), publish_input(unit.id))

    assert {:ok, _} = Foundation.current_institution(f.runtime, context_a(), unit.id)
  end

  test "concurrent publication retry has one result and one durable event", f do
    unit = register!(f)
    assignment = assignment_input(f, unit)
    assert {:ok, _} = Foundation.assign_initial_operator(f.runtime, context_a(), assignment)
    input = publish_input(unit.id)

    results =
      Task.async_stream(1..3, fn _ ->
        Foundation.publish_institution(f.runtime, context_a(), input)
      end)
      |> Enum.map(fn {:ok, value} -> value end)

    assert [{:ok, %{status: :published}}] = Enum.uniq(results)
    assert [[3, 3, 3]] = facts(f)
  end

  test "database rejects cross-tenant operator references and wrong-institution publication", f do
    one = register!(f)
    two = register!(f)
    first = assignment_input(f, one)
    second = assignment_input(f, two)
    assert {:ok, _} = Foundation.assign_initial_operator(f.runtime, context_a(), first)
    assert {:ok, _} = Foundation.assign_initial_operator(f.runtime, context_a(), second)
    assert {:ok, first_view} = Foundation.current_institution(f.runtime, context_a(), one.id)

    assert {:error, %Postgrex.Error{}} =
             query(
               f,
               "INSERT INTO institution_publications (id, tenant_id, institutional_unit_id, operator_assignment_id, verification, recorded_by_actor_id, inserted_at) VALUES ($1, $2, $3, $4, '{}'::jsonb, $5, NOW())",
               [
                 dump(UUID.generate()),
                 dump(@tenant_a),
                 dump(two.id),
                 dump(first_view.operator_assignment_id),
                 dump(@actor_a)
               ]
             )

    foreign = assignment_input(f, register!(f), context_b())

    assert {:error, %Postgrex.Error{}} =
             query(
               f,
               "INSERT INTO institution_initial_operator_assignments (id, tenant_id, institutional_unit_id, legal_entity_id, legal_entity_version, evidence_reference, effective_from, verification, recorded_by_actor_id, inserted_at) VALUES ($1, $2, $3, $4, 1, $5, CURRENT_DATE, '{}'::jsonb, $6, NOW())",
               [
                 dump(UUID.generate()),
                 dump(@tenant_a),
                 dump(foreign.institutional_unit_id),
                 dump(foreign.legal_entity_id),
                 dump(UUID.generate()),
                 dump(@actor_a)
               ]
             )
  end

  test "database refuses an empty proof for the correct institution and operator", f do
    unit = register!(f)
    assignment = assignment_input(f, unit)

    assert {:error, %Postgrex.Error{postgres: %{message: "invalid institutional proof"}}} =
             query(
               f,
               "INSERT INTO institution_initial_operator_assignments (id, tenant_id, institutional_unit_id, legal_entity_id, legal_entity_version, evidence_reference, effective_from, verification, recorded_by_actor_id, inserted_at) VALUES ($1, $2, $3, $4, 1, $5, $6, '{}'::jsonb, $7, NOW())",
               [
                 dump(UUID.generate()),
                 dump(@tenant_a),
                 dump(unit.id),
                 dump(assignment.legal_entity_id),
                 dump(assignment.evidence_reference),
                 assignment.effective_from,
                 dump(@actor_a)
               ]
             )

    assert {:ok, _} = Foundation.assign_initial_operator(f.runtime, context_a(), assignment)
    assert {:ok, view} = Foundation.current_institution(f.runtime, context_a(), unit.id)

    assert {:error, %Postgrex.Error{postgres: %{message: "invalid institutional proof"}}} =
             query(
               f,
               "INSERT INTO institution_publications (id, tenant_id, institutional_unit_id, operator_assignment_id, verification, recorded_by_actor_id, inserted_at) VALUES ($1, $2, $3, $4, '{}'::jsonb, $5, NOW())",
               [
                 dump(UUID.generate()),
                 dump(@tenant_a),
                 dump(unit.id),
                 dump(view.operator_assignment_id),
                 dump(@actor_a)
               ]
             )

    assert [[2, 2, 2]] = facts(f)
  end

  test "publication uses the institution's local date across the date line", f do
    for zone <- ["Pacific/Kiritimati", "Pacific/Pago_Pago"] do
      assert {:ok, unit} =
               Foundation.register_institution(f.runtime, context_a(), %{
                 register_input()
                 | time_zone: zone
               })

      assert {:ok, %{rows: [[local_date]]}} =
               query(f, "SELECT (statement_timestamp() AT TIME ZONE $1)::date", [zone])

      assignment = %{assignment_input(f, unit) | effective_from: local_date}
      assert {:ok, _} = Foundation.assign_initial_operator(f.runtime, context_a(), assignment)

      assert {:ok, %{status: :published}} =
               Foundation.publish_institution(f.runtime, context_a(), publish_input(unit.id))
    end
  end

  defp register_input do
    %{
      display_name: "Synthetic Learning Institution",
      time_zone: "Etc/UTC",
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  defp register!(f) do
    assert {:ok, unit} = Foundation.register_institution(f.runtime, context_a(), register_input())
    unit
  end

  defp publish_input(id),
    do: %{
      institutional_unit_id: id,
      expected_version: 2,
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }

  defp assignment_input(f, unit, context \\ context_a()) do
    assert {:ok, entity} =
             LegalFoundation.register_legal_entity(f.persistence, context, %{
               official_name: "Synthetic Operator",
               display_name: "Operator",
               idempotency_key: UUID.generate(),
               causation_id: UUID.generate()
             })

    reference = UUID.generate()

    binding = %{
      tenant_id: TrustedActor.tenant_id(context.actor),
      institutional_unit_id: unit.id,
      legal_entity_id: entity.id
    }

    Agent.update(f.source, &put_in(&1, [:records, reference], binding))

    %{
      institutional_unit_id: unit.id,
      expected_version: 1,
      legal_entity_id: entity.id,
      legal_entity_version: entity.lock_version,
      evidence_reference: reference,
      effective_from: Date.utc_today(),
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  defp query(f, sql, params \\ []) do
    {:ok, value} =
      Persistence.with_writer(f.persistence, context_a(), fn -> Repo.query(sql, params) end)

    value
  end

  defp facts(f) do
    {:ok, %{rows: rows}} =
      query(
        f,
        "SELECT (SELECT count(*) FROM platform_authority_audit_events WHERE action_name LIKE 'institution.structure.%'), (SELECT count(*) FROM platform_outbox_events WHERE aggregate_type = 'institution.structure.unit'), (SELECT count(*) FROM platform_authority_action_idempotency WHERE action_name LIKE 'institution.structure.%')"
      )

    rows
  end

  defp seed_foundation(runtime) do
    ids = %{
      membership_a: UUID.generate(),
      membership_a_peer: UUID.generate(),
      membership_a_denied: UUID.generate(),
      membership_b: UUID.generate(),
      role_a: UUID.generate(),
      role_b: UUID.generate(),
      manage_capability_a: UUID.generate(),
      read_capability_a: UUID.generate(),
      assign_capability_a: UUID.generate(),
      publish_capability_a: UUID.generate(),
      manage_capability_b: UUID.generate(),
      read_capability_b: UUID.generate(),
      assign_capability_b: UUID.generate(),
      publish_capability_b: UUID.generate()
    }

    seed_tenant(
      runtime,
      context_a(),
      @tenant_a,
      [
        {ids.membership_a, @actor_a, true},
        {ids.membership_a_peer, @actor_a_peer, true},
        {ids.membership_a_denied, @actor_a_denied, false}
      ],
      ids.role_a,
      %{
        manage: ids.manage_capability_a,
        read: ids.read_capability_a,
        relationships: ids.assign_capability_a,
        corporate_units: ids.publish_capability_a
      }
    )

    seed_tenant(
      runtime,
      context_b(),
      @tenant_b,
      [{ids.membership_b, @actor_b, true}],
      ids.role_b,
      %{
        manage: ids.manage_capability_b,
        read: ids.read_capability_b,
        relationships: ids.assign_capability_b,
        corporate_units: ids.publish_capability_b
      }
    )

    ids
  end

  defp seed_tenant(
         runtime,
         context,
         tenant_id,
         memberships,
         role_id,
         capability_ids
       ) do
    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context, fn ->
               insert_role(role_id, tenant_id)

               Enum.each(
                 memberships,
                 &seed_membership(&1, tenant_id, role_id)
               )

               insert_capability(capability_ids.manage, tenant_id, @manage_capability)
               insert_capability(capability_ids.read, tenant_id, @read_capability)

               insert_capability(
                 capability_ids.relationships,
                 tenant_id,
                 @assign_capability
               )

               insert_capability(
                 capability_ids.corporate_units,
                 tenant_id,
                 @publish_capability
               )

               insert_grant(tenant_id, role_id, capability_ids.manage)
               insert_grant(tenant_id, role_id, capability_ids.read)
               insert_grant(tenant_id, role_id, capability_ids.relationships)
               insert_grant(tenant_id, role_id, capability_ids.corporate_units)
               extra = UUID.generate()
               insert_capability(extra, tenant_id, "organization.legal.entities.manage")
               insert_grant(tenant_id, role_id, extra)
               insert_active_module(tenant_id)
               :seeded
             end)
  end

  defp seed_membership({membership_id, actor_id, assigned?}, tenant_id, role_id) do
    insert_membership(membership_id, tenant_id, actor_id)
    if assigned?, do: insert_assignment(tenant_id, membership_id, role_id)
  end

  defp insert_membership(id, tenant_id, actor_id) do
    Repo.query!(
      """
      INSERT INTO platform_tenant_memberships
        (id, tenant_id, actor_id, inserted_at, updated_at)
      VALUES ($1, $2, $3, NOW(), NOW())
      """,
      Enum.map([id, tenant_id, actor_id], &dump/1)
    )
  end

  defp insert_role(id, tenant_id) do
    Repo.query!(
      """
      INSERT INTO platform_roles
        (id, tenant_id, name, lock_version, inserted_at, updated_at)
      VALUES ($1, $2, 'Legal structure manager', 1, NOW(), NOW())
      """,
      Enum.map([id, tenant_id], &dump/1)
    )
  end

  defp insert_capability(id, tenant_id, key) do
    Repo.query!(
      """
      INSERT INTO platform_capabilities
        (id, tenant_id, key, inserted_at, updated_at)
      VALUES ($1, $2, $3, NOW(), NOW())
      """,
      [dump(id), dump(tenant_id), key]
    )
  end

  defp insert_assignment(tenant_id, membership_id, role_id) do
    Repo.query!(
      """
      INSERT INTO platform_actor_role_assignments
        (id, tenant_id, membership_id, role_id, lock_version, inserted_at)
      VALUES ($1, $2, $3, $4, 1, NOW())
      """,
      Enum.map([UUID.generate(), tenant_id, membership_id, role_id], &dump/1)
    )
  end

  defp insert_grant(tenant_id, role_id, capability_id) do
    Repo.query!(
      """
      INSERT INTO platform_role_capability_grants
        (id, tenant_id, role_id, capability_id, inserted_at)
      VALUES ($1, $2, $3, $4, NOW())
      """,
      Enum.map([UUID.generate(), tenant_id, role_id, capability_id], &dump/1)
    )
  end

  defp insert_active_module(tenant_id) do
    for {key, version} <- [{"organization.legal", "1.2.0"}, {"institution.structure", "1.0.0"}] do
      entitlement = UUID.generate()

      Repo.query!(
        "INSERT INTO platform_module_entitlements (id, tenant_id, module_key, inserted_at) VALUES ($1, $2, $3, NOW())",
        [dump(entitlement), dump(tenant_id), key]
      )

      Repo.query!(
        "INSERT INTO platform_module_activations (id, tenant_id, entitlement_id, module_version, state, lock_version, activated_at, inserted_at, updated_at) VALUES ($1, $2, $3, $4, 'active', 1, NOW(), NOW(), NOW())",
        [dump(UUID.generate()), dump(tenant_id), dump(entitlement), version]
      )
    end
  end

  defp install_completion_failure(runtime) do
    assert {:ok, :installed} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_institution_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_institution_completion()")

               Repo.query!("""
               CREATE FUNCTION test_fail_institution_completion()
               RETURNS trigger
               LANGUAGE plpgsql
               AS $$
               BEGIN
                 IF NEW.status = 'completed' AND
                    NEW.action_name LIKE 'institution.structure.%' THEN
                   RAISE EXCEPTION USING
                     ERRCODE = '40001',
                     MESSAGE = 'synthetic legal entity completion failure';
                 END IF;

                 RETURN NEW;
               END;
               $$;
               """)

               Repo.query!("""
               CREATE TRIGGER test_fail_institution_completion
               BEFORE UPDATE OF status
               ON platform_authority_action_idempotency
               FOR EACH ROW
               EXECUTE FUNCTION test_fail_institution_completion();
               """)

               :installed
             end)
  end

  defp remove_completion_failure(runtime) do
    assert {:ok, :removed} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_institution_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_institution_completion()")
               :removed
             end)
  end

  defp clear_fixture(runtime) do
    assert {:ok, :cleared} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!("""
               TRUNCATE
                 classroom_attendance_submissions,
                 classroom_attendance_exposures,
                 classroom_placements,
                 classroom_teaching_assignments,
                 classroom_enrolments,
                 classroom_classes,
                 people_staff_account_associations,
                 people_participations,
                 people_persons,
                 academic_calendar_closures,
                 academic_periods,
                 academic_years,
                 academic_calendars,
                 institution_publications,
                 institution_initial_operator_assignments,
                 institutional_units,
                 organization_legal_entity_relationship_terminations,
                 organization_legal_corporate_unit_profile_revisions,
                 organization_legal_corporate_units,
                 organization_legal_entity_relationships,
                 organization_legal_entity_consolidation_parentages,
                 organization_legal_entity_profile_revisions,
                 organization_legal_entities
               """)

               :cleared
             end)

    Enum.each([context_a(), context_b()], fn context ->
      assert {:ok, :cleared} = clear_tenant(runtime, context)
    end)
  end

  defp clear_tenant(runtime, context) do
    Persistence.with_writer(runtime, context, fn ->
      tenant_id = dump(TrustedActor.tenant_id(context.actor))

      for table <- [
            "platform_governed_extension_definitions",
            "platform_authority_action_idempotency",
            "platform_outbox_consumer_receipts",
            "platform_outbox_deliveries",
            "platform_outbox_events",
            "platform_authority_audit_events",
            "platform_module_work_items",
            "platform_module_activations",
            "platform_module_entitlements",
            "platform_role_inclusions",
            "platform_role_capability_grants",
            "platform_actor_role_assignments",
            "platform_capabilities",
            "platform_roles",
            "platform_tenant_memberships"
          ] do
        Repo.query!("DELETE FROM #{table} WHERE tenant_id = $1", [tenant_id])
      end

      :cleared
    end)
  end

  defp runtime_options do
    [
      repositories: [pooled: [log: false, pool: DBConnection.ConnectionPool, pool_size: 6]],
      placements: [
        placement(@tenant_a, "pooled-organization-legal", :pooled),
        placement(@tenant_b, "pooled-organization-legal", :pooled)
      ],
      per_tenant_limit: 6,
      per_placement_limit: 12
    ]
  end

  defp placement(tenant_id, placement_ref, repository) do
    [
      tenant_id: tenant_id,
      routing_version: 9,
      profile: :pooled,
      placement_ref: placement_ref,
      repository: repository
    ]
  end

  defp context_a(correlation_id \\ UUID.generate()),
    do: context(@actor_a, @tenant_a, correlation_id)

  defp context_a_peer, do: context(@actor_a_peer, @tenant_a, UUID.generate())
  defp context_a_denied, do: context(@actor_a_denied, @tenant_a, UUID.generate())
  defp context_b, do: context(@actor_b, @tenant_b, UUID.generate())

  defp context(actor_id, tenant_id, correlation_id) do
    {:ok, actor} =
      TrustedActor.establish(actor_id: actor_id, tenant_id: tenant_id, assurance: "mfa")

    {:ok, placement} =
      TrustedPlacement.establish(
        tenant_id: tenant_id,
        routing_version: 9,
        profile: :pooled,
        placement_ref: "pooled-organization-legal"
      )

    {:ok, context} =
      ExecutionContext.establish(
        actor,
        placement,
        correlation_id: correlation_id,
        purpose: "organization.legal.entity",
        locale: "en"
      )

    context
  end

  defp dump(uuid), do: UUID.dump!(uuid)
end
