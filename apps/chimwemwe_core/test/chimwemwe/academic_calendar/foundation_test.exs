defmodule Chimwemwe.AcademicCalendar.FoundationTest do
  use ExUnit.Case, async: false

  alias Chimwemwe.AcademicCalendar.{Error, Foundation, Runtime}
  alias Chimwemwe.InstitutionalStructure.Foundation, as: Institutions
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

  @institution_capabilities [
    "institution.structure.institutions.register",
    "institution.structure.institutions.read",
    "institution.structure.operators.assign_initial",
    "institution.structure.institutions.publish"
  ]
  @calendar_capabilities [
    "academics.calendar.definition.manage",
    "academics.calendar.publication.publish",
    "academics.calendar.read"
  ]

  setup do
    persistence = start_supervised!({PersistenceRuntime, runtime_options()})
    clear_fixture(persistence)
    ids = seed_foundation(persistence)
    source = start_supervised!({Agent, fn -> %{records: %{}, overrides: %{}, calls: 0} end})

    {:ok, institution_runtime} =
      Chimwemwe.InstitutionalStructure.Runtime.new(
        persistence,
        Chimwemwe.InstitutionalStructure.TestVerifier,
        source
      )

    {:ok, runtime} = Runtime.new(persistence)

    fixture =
      ids
      |> Map.merge(%{
        persistence: persistence,
        institution_runtime: institution_runtime,
        runtime: runtime,
        source: source
      })
      |> publish_institution!()

    {:ok, fixture}
  end

  test "closed resources expose named writer actions only" do
    assert :ok = ResourceContract.validate_domain(Chimwemwe.AcademicCalendar)

    for resource <- Ash.Domain.Info.resources(Chimwemwe.AcademicCalendar),
        do: assert(Ash.Resource.Info.actions(resource) == [])

    assert {:error, :invalid_runtime} = Runtime.new({:caller, :selected, :repository})
  end

  test "register, define, preview, publish, exact read and date resolution are authoritative",
       f do
    calendar_input = calendar_input(f.unit.id)

    assert {:ok, calendar} =
             Foundation.register_academic_calendar(f.runtime, context_a(), calendar_input)

    assert {:ok, ^calendar} =
             Foundation.register_academic_calendar(f.runtime, context_a(), calendar_input)

    definition = definition(calendar.id)

    assert {:ok, draft} =
             Foundation.define_draft_academic_year(f.runtime, context_a(), definition)

    assert draft.status == :draft and draft.lock_version == 1
    assert is_binary(draft.candidate_revision)

    assert {:ok, preview} =
             Foundation.preview_academic_year_publication(
               f.runtime,
               context_a(),
               calendar.id,
               definition.academic_year_id
             )

    assert preview.lock_version == 1
    assert preview.preview.candidate_revision == draft.candidate_revision

    publish = publish_input(calendar.id, definition.academic_year_id, 1)

    assert {:ok, published} =
             Foundation.publish_academic_year(f.runtime, context_a(), publish)

    assert published.status == :published and published.lock_version == 2
    assert {:ok, ^published} = Foundation.publish_academic_year(f.runtime, context_a(), publish)

    assert {:ok, view} =
             Foundation.read_published_academic_year(
               f.runtime,
               context_a(),
               calendar.id,
               definition.academic_year_id
             )

    assert view.status == :published and view.lock_version == 2
    assert view.preview.definition.institutional_unit_id == f.unit.id

    assert {:ok, %{status: :instructional, reason: :instructional_weekday}} =
             Foundation.resolve_instructional_context(
               f.runtime,
               context_a(),
               calendar.id,
               ~D[2026-09-02]
             )

    assert {:ok, %{status: :non_instructional, reason: :closure}} =
             Foundation.resolve_instructional_context(
               f.runtime,
               context_a(),
               calendar.id,
               ~D[2026-10-12]
             )

    assert [[3, 3, 3]] = facts(f)

    assert {:ok, %{rows: payloads}} =
             query(
               f,
               "SELECT payload FROM platform_outbox_events WHERE aggregate_type LIKE 'academics.calendar.%' ORDER BY inserted_at"
             )

    assert Enum.all?(payloads, fn [payload] ->
             Enum.sort(Map.keys(payload)) ==
               ["candidate_revision", "id", "kind", "lock_version", "status"]
           end)
  end

  test "draft replacement is versioned and publication freezes the definition", f do
    {calendar, draft_input, draft} = draft!(f)

    replacement =
      Map.merge(draft_input, %{
        label: "2026 to 2027 revised",
        expected_version: draft.lock_version,
        idempotency_key: UUID.generate(),
        causation_id: UUID.generate()
      })

    assert {:ok, revised} =
             Foundation.replace_draft_calendar_definition(
               f.runtime,
               context_a(),
               replacement
             )

    assert revised.lock_version == 2
    refute revised.candidate_revision == draft.candidate_revision

    assert {:error, %Error{code: :stale}} =
             Foundation.replace_draft_calendar_definition(
               f.runtime,
               context_a(),
               %{replacement | idempotency_key: UUID.generate()}
             )

    assert {:ok, published} =
             Foundation.publish_academic_year(
               f.runtime,
               context_a(),
               publish_input(calendar.id, draft_input.academic_year_id, 2)
             )

    assert published.lock_version == 3

    assert {:error, %Error{code: :conflict}} =
             Foundation.replace_draft_calendar_definition(
               f.runtime,
               context_a(),
               %{replacement | expected_version: 3, idempotency_key: UUID.generate()}
             )

    assert {:error, %Postgrex.Error{}} =
             query(
               f,
               "UPDATE academic_years SET label = 'Changed', lock_version = lock_version + 1 WHERE id = $1",
               [dump(draft_input.academic_year_id)]
             )
  end

  test "context, capability, module and tenant boundaries fail closed", f do
    input = calendar_input(f.unit.id)
    assert {:error, _} = Foundation.register_academic_calendar(f.runtime, nil, input)

    assert {:error, %Error{code: :forbidden}} =
             Foundation.register_academic_calendar(f.runtime, context_a_denied(), input)

    for extra <- [%{tenant_id: @tenant_b}, %{current: true}, %{repository: :pooled}] do
      assert {:error, %Error{code: :invalid_input}} =
               Foundation.register_academic_calendar(
                 f.runtime,
                 context_a(),
                 Map.merge(input, extra)
               )
    end

    assert {:error, %Error{code: :not_found}} =
             Foundation.register_academic_calendar(f.runtime, context_b(), input)

    {calendar, definition, _draft} = draft!(f)

    assert {:error, %Error{code: :not_found}} =
             Foundation.preview_academic_year_publication(
               f.runtime,
               context_b(),
               calendar.id,
               definition.academic_year_id
             )

    deny(f, "academics.calendar.publication.publish")

    assert {:error, %Error{code: :forbidden}} =
             Foundation.publish_academic_year(
               f.runtime,
               context_a(),
               publish_input(calendar.id, definition.academic_year_id, 1)
             )

    reactivate_capability(f, "academics.calendar.publication.publish")
    deactivate_module(f, "institution.structure")

    assert {:error, %Error{code: :module_unavailable}} =
             Foundation.publish_academic_year(
               f.runtime,
               context_a(),
               publish_input(calendar.id, definition.academic_year_id, 1)
             )
  end

  test "idempotency is exact and rollback removes state, audit and outbox", f do
    input = calendar_input(f.unit.id)

    results =
      1..3
      |> Task.async_stream(
        fn _ -> Foundation.register_academic_calendar(f.runtime, context_a(), input) end,
        max_concurrency: 3
      )
      |> Enum.map(fn {:ok, result} -> result end)

    assert [{:ok, calendar}] = Enum.uniq(results)

    assert {:error, %Error{code: :idempotency_conflict}} =
             Foundation.register_academic_calendar(f.runtime, context_a_peer(), input)

    assert {:error, %Error{code: :idempotency_conflict}} =
             Foundation.register_academic_calendar(f.runtime, context_a(), %{
               input
               | code: "other"
             })

    install_completion_failure(f.persistence)

    try do
      assert {:error, %Error{code: :retryable_dependency}} =
               Foundation.define_draft_academic_year(
                 f.runtime,
                 context_a(),
                 definition(calendar.id)
               )

      assert {:ok, %{rows: [[0]]}} =
               query(f, "SELECT count(*) FROM academic_years WHERE calendar_id = $1", [
                 dump(calendar.id)
               ])

      assert [[1, 1, 1]] = facts(f)
    after
      remove_completion_failure(f.persistence)
    end
  end

  test "concurrent overlapping publications leave only one published year", f do
    assert {:ok, calendar} =
             Foundation.register_academic_calendar(
               f.runtime,
               context_a(),
               calendar_input(f.unit.id)
             )

    first = definition(calendar.id)

    second = %{
      definition(calendar.id)
      | academic_year_id: UUID.generate(),
        code: "competing_year",
        idempotency_key: UUID.generate()
    }

    assert {:ok, _} = Foundation.define_draft_academic_year(f.runtime, context_a(), first)
    assert {:ok, _} = Foundation.define_draft_academic_year(f.runtime, context_a(), second)

    results =
      [first, second]
      |> Task.async_stream(
        fn candidate ->
          Foundation.publish_academic_year(
            f.runtime,
            context_a(),
            publish_input(calendar.id, candidate.academic_year_id, 1)
          )
        end,
        max_concurrency: 2
      )
      |> Enum.map(fn {:ok, result} -> result end)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1

    assert Enum.count(results, fn
             {:error, %Error{code: code}} when code in [:conflict, :overlap] -> true
             _result -> false
           end) == 1

    assert {:ok, %{rows: [[1]]}} =
             query(
               f,
               "SELECT count(*) FROM academic_years WHERE calendar_id = $1 AND status = 'published'",
               [dump(calendar.id)]
             )
  end

  test "writer and database reject unsupported zones, overlap and direct publication bypass", f do
    assert {:ok, calendar} =
             Foundation.register_academic_calendar(
               f.runtime,
               context_a(),
               calendar_input(f.unit.id)
             )

    assert {:error, %Error{code: :unsupported_time_zone}} =
             Foundation.define_draft_academic_year(f.runtime, context_a(), %{
               definition(calendar.id)
               | time_zone: "Mars/Olympus",
                 academic_year_id: UUID.generate(),
                 idempotency_key: UUID.generate()
             })

    one = definition(calendar.id)
    assert {:ok, _} = Foundation.define_draft_academic_year(f.runtime, context_a(), one)

    assert {:ok, _} =
             Foundation.publish_academic_year(
               f.runtime,
               context_a(),
               publish_input(calendar.id, one.academic_year_id, 1)
             )

    two = %{
      definition(calendar.id)
      | academic_year_id: UUID.generate(),
        code: "overlap",
        periods: [
          period("semester", "Overlap", 1, ~D[2027-01-01], ~D[2027-12-20])
        ],
        start_on: ~D[2027-01-01],
        end_on: ~D[2027-12-20],
        closures: [],
        idempotency_key: UUID.generate()
    }

    assert {:ok, _} = Foundation.define_draft_academic_year(f.runtime, context_a(), two)

    assert {:error, %Error{code: :overlap}} =
             Foundation.publish_academic_year(
               f.runtime,
               context_a(),
               publish_input(calendar.id, two.academic_year_id, 1)
             )

    assert {:error,
            %Postgrex.Error{postgres: %{message: "calendar transition lacks atomic evidence"}}} =
             query(
               f,
               "INSERT INTO academic_calendars (id, tenant_id, institutional_unit_id, code, status, lock_version, inserted_at, updated_at) VALUES ($1, $2, $3, 'bypass', 'active', 1, NOW(), NOW())",
               [dump(UUID.generate()), dump(@tenant_a), dump(f.unit.id)]
             )

    assert {:error, %Postgrex.Error{}} =
             query(
               f,
               "UPDATE academic_years SET status = 'published', lock_version = lock_version + 1 WHERE id = $1",
               [dump(two.academic_year_id)]
             )
  end

  defp draft!(f) do
    assert {:ok, calendar} =
             Foundation.register_academic_calendar(
               f.runtime,
               context_a(),
               calendar_input(f.unit.id)
             )

    input = definition(calendar.id)
    assert {:ok, draft} = Foundation.define_draft_academic_year(f.runtime, context_a(), input)
    {calendar, input, draft}
  end

  defp calendar_input(unit_id),
    do: %{
      institutional_unit_id: unit_id,
      code: "calendar_" <> String.replace(UUID.generate(), "-", ""),
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }

  defp definition(calendar_id),
    do: %{
      academic_year_id: UUID.generate(),
      calendar_id: calendar_id,
      code: "year_2026_2027",
      label: "2026 to 2027",
      start_on: ~D[2026-09-01],
      end_on: ~D[2027-06-30],
      time_zone: "Europe/Brussels",
      instructional_weekdays: [1, 2, 3, 4, 5],
      periods: [
        period("term", "Term 1", 1, ~D[2026-09-01], ~D[2026-12-18]),
        period("term", "Term 2", 2, ~D[2027-01-04], ~D[2027-03-26]),
        period("term", "Term 3", 3, ~D[2027-04-12], ~D[2027-06-30])
      ],
      closures: [
        %{
          id: UUID.generate(),
          date: ~D[2026-10-12],
          reason_key: "public_holiday",
          label: "Closure"
        }
      ],
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }

  defp period(type, label, sequence, start_on, end_on),
    do: %{
      id: UUID.generate(),
      period_type_key: type,
      label: label,
      sequence: sequence,
      start_on: start_on,
      end_on: end_on
    }

  defp publish_input(calendar_id, academic_year_id, expected_version),
    do: %{
      calendar_id: calendar_id,
      academic_year_id: academic_year_id,
      expected_version: expected_version,
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }

  defp publish_institution!(f) do
    assert {:ok, unit} =
             Institutions.register_institution(f.institution_runtime, context_a(), %{
               display_name: "Synthetic Calendar Institution",
               time_zone: "Europe/Brussels",
               idempotency_key: UUID.generate(),
               causation_id: UUID.generate()
             })

    assert {:ok, entity} =
             LegalFoundation.register_legal_entity(f.persistence, context_a(), %{
               official_name: "Synthetic Calendar Operator",
               display_name: "Calendar Operator",
               idempotency_key: UUID.generate(),
               causation_id: UUID.generate()
             })

    reference = UUID.generate()

    Agent.update(f.source, fn state ->
      put_in(state, [:records, reference], %{
        tenant_id: @tenant_a,
        institutional_unit_id: unit.id,
        legal_entity_id: entity.id
      })
    end)

    assert {:ok, _} =
             Institutions.assign_initial_operator(f.institution_runtime, context_a(), %{
               institutional_unit_id: unit.id,
               expected_version: 1,
               legal_entity_id: entity.id,
               legal_entity_version: entity.lock_version,
               evidence_reference: reference,
               effective_from: local_date(f, "Europe/Brussels"),
               idempotency_key: UUID.generate(),
               causation_id: UUID.generate()
             })

    assert {:ok, _} =
             Institutions.publish_institution(f.institution_runtime, context_a(), %{
               institutional_unit_id: unit.id,
               expected_version: 2,
               idempotency_key: UUID.generate(),
               causation_id: UUID.generate()
             })

    Map.put(f, :unit, unit)
  end

  defp local_date(f, zone) do
    {:ok, %{rows: [[date]]}} =
      query(f, "SELECT (statement_timestamp() AT TIME ZONE $1)::date", [zone])

    date
  end

  defp facts(f) do
    {:ok, %{rows: rows}} =
      query(
        f,
        "SELECT (SELECT count(*) FROM platform_authority_audit_events WHERE action_name LIKE 'academics.calendar.%'), (SELECT count(*) FROM platform_outbox_events WHERE aggregate_type LIKE 'academics.calendar.%'), (SELECT count(*) FROM platform_authority_action_idempotency WHERE action_name LIKE 'academics.calendar.%')"
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
      role_b: UUID.generate()
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
      ids.role_a
    )

    seed_tenant(
      runtime,
      context_b(),
      @tenant_b,
      [{ids.membership_b, @actor_b, true}],
      ids.role_b
    )

    ids
  end

  defp seed_tenant(runtime, context, tenant_id, memberships, role_id) do
    assert {:ok, :seeded} =
             Persistence.with_writer(
               runtime,
               context,
               fn -> seed_tenant_records(tenant_id, memberships, role_id) end
             )
  end

  defp seed_tenant_records(tenant_id, memberships, role_id) do
    insert_role(role_id, tenant_id)

    Enum.each(memberships, &seed_membership(&1, tenant_id, role_id))

    for capability <-
          ["organization.legal.entities.manage"] ++
            @institution_capabilities ++ @calendar_capabilities do
      capability_id = UUID.generate()
      insert_capability(capability_id, tenant_id, capability)
      insert_grant(tenant_id, role_id, capability_id)
    end

    insert_active_modules(tenant_id)
    :seeded
  end

  defp seed_membership({membership_id, actor_id, assigned?}, tenant_id, role_id) do
    insert_membership(membership_id, tenant_id, actor_id)
    if assigned?, do: insert_assignment(tenant_id, membership_id, role_id)
  end

  defp insert_membership(id, tenant_id, actor_id) do
    Repo.query!(
      "INSERT INTO platform_tenant_memberships (id, tenant_id, actor_id, inserted_at, updated_at) VALUES ($1, $2, $3, NOW(), NOW())",
      Enum.map([id, tenant_id, actor_id], &dump/1)
    )
  end

  defp insert_role(id, tenant_id) do
    Repo.query!(
      "INSERT INTO platform_roles (id, tenant_id, name, lock_version, inserted_at, updated_at) VALUES ($1, $2, 'Calendar manager', 1, NOW(), NOW())",
      Enum.map([id, tenant_id], &dump/1)
    )
  end

  defp insert_capability(id, tenant_id, key) do
    Repo.query!(
      "INSERT INTO platform_capabilities (id, tenant_id, key, inserted_at, updated_at) VALUES ($1, $2, $3, NOW(), NOW())",
      [dump(id), dump(tenant_id), key]
    )
  end

  defp insert_assignment(tenant_id, membership_id, role_id) do
    Repo.query!(
      "INSERT INTO platform_actor_role_assignments (id, tenant_id, membership_id, role_id, lock_version, inserted_at) VALUES ($1, $2, $3, $4, 1, NOW())",
      Enum.map([UUID.generate(), tenant_id, membership_id, role_id], &dump/1)
    )
  end

  defp insert_grant(tenant_id, role_id, capability_id) do
    Repo.query!(
      "INSERT INTO platform_role_capability_grants (id, tenant_id, role_id, capability_id, inserted_at) VALUES ($1, $2, $3, $4, NOW())",
      Enum.map([UUID.generate(), tenant_id, role_id, capability_id], &dump/1)
    )
  end

  defp insert_active_modules(tenant_id) do
    for {key, version} <- [
          {"organization.legal", "1.2.0"},
          {"institution.structure", "1.0.0"},
          {"academics.calendar", "1.0.0"}
        ] do
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

  defp deny(f, capability) do
    assert {:ok, _} =
             query(
               f,
               "DELETE FROM platform_role_capability_grants grant_row USING platform_capabilities capability WHERE grant_row.tenant_id = $1 AND grant_row.role_id = $2 AND capability.tenant_id = grant_row.tenant_id AND capability.id = grant_row.capability_id AND capability.key = $3",
               [dump(@tenant_a), dump(f.role_a), capability]
             )
  end

  defp reactivate_capability(f, capability) do
    assert {:ok, _} =
             query(
               f,
               "INSERT INTO platform_role_capability_grants (id, tenant_id, role_id, capability_id, inserted_at) SELECT $1, $2, $3, id, NOW() FROM platform_capabilities WHERE tenant_id = $2 AND key = $4",
               [dump(UUID.generate()), dump(@tenant_a), dump(f.role_a), capability]
             )
  end

  defp deactivate_module(f, module_key) do
    assert {:ok, _} =
             query(
               f,
               "UPDATE platform_module_activations activation SET state = 'inactive', replay_from_cursor = consumer_cursor, projection_ready = false, reconciliation_required = true, deactivated_at = NOW() FROM platform_module_entitlements entitlement WHERE activation.entitlement_id = entitlement.id AND entitlement.tenant_id = $1 AND entitlement.module_key = $2",
               [dump(@tenant_a), module_key]
             )
  end

  defp install_completion_failure(runtime) do
    assert {:ok, :installed} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_calendar_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_calendar_completion()")

               Repo.query!("""
               CREATE FUNCTION test_fail_calendar_completion() RETURNS trigger LANGUAGE plpgsql AS $$
               BEGIN
                 IF NEW.status = 'completed' AND NEW.action_name LIKE 'academics.calendar.%' THEN
                   RAISE EXCEPTION USING ERRCODE = '40001', MESSAGE = 'synthetic calendar completion failure';
                 END IF;
                 RETURN NEW;
               END $$;
               """)

               Repo.query!("""
               CREATE TRIGGER test_fail_calendar_completion
               BEFORE UPDATE OF status ON platform_authority_action_idempotency
               FOR EACH ROW EXECUTE FUNCTION test_fail_calendar_completion();
               """)

               :installed
             end)
  end

  defp remove_completion_failure(runtime) do
    assert {:ok, :removed} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_calendar_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_calendar_completion()")
               :removed
             end)
  end

  defp clear_fixture(runtime) do
    assert {:ok, :cleared} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!("""
               TRUNCATE
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
        placement(@tenant_a, "pooled-calendar", :pooled),
        placement(@tenant_b, "pooled-calendar", :pooled)
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
        placement_ref: "pooled-calendar"
      )

    {:ok, context} =
      ExecutionContext.establish(
        actor,
        placement,
        correlation_id: correlation_id,
        purpose: "academics.calendar",
        locale: "en"
      )

    context
  end

  defp query(f, sql, params \\ []) do
    {:ok, result} =
      Persistence.with_writer(f.persistence, context_a(), fn -> Repo.query(sql, params) end)

    result
  end

  defp dump(value), do: UUID.dump!(value)
end
