defmodule Chimwemwe.People.FoundationTest do
  use ExUnit.Case, async: false
  alias Chimwemwe.InstitutionalStructure.Foundation, as: Institutions
  alias Chimwemwe.OrganizationLegal.Foundation, as: LegalFoundation
  alias Chimwemwe.People.{Error, Foundation, Runtime, TestVerifier}

  alias Chimwemwe.Platform.{
    ExecutionContext,
    Outbox,
    Persistence,
    PersistenceRuntime,
    ResourceContract,
    TrustedActor,
    TrustedPlacement
  }

  alias Chimwemwe.Platform.Outbox.ConsumerRegistry
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

  @people_capabilities [
    "persons.register",
    "persons.revise_name",
    "persons.read",
    "participations.record_student",
    "participations.record_staff",
    "participations.end",
    "participations.read",
    "accounts.associate_staff",
    "accounts.revoke",
    "accounts.read"
  ]
  setup do
    persistence = start_supervised!({PersistenceRuntime, runtime_options()})
    clear_fixture(persistence)
    ids = seed_foundation(persistence)
    {:ok, source} = Agent.start_link(fn -> %{records: %{}, overrides: %{}, calls: 0} end)

    {:ok, institution_runtime} =
      Chimwemwe.InstitutionalStructure.Runtime.new(
        persistence,
        Chimwemwe.InstitutionalStructure.TestVerifier,
        source
      )

    {:ok, account_source} = Agent.start_link(fn -> %{records: %{}, overrides: %{}, calls: 0} end)
    {:ok, runtime} = Runtime.new(persistence, TestVerifier, account_source)

    f =
      Map.merge(ids, %{
        persistence: persistence,
        institution_runtime: institution_runtime,
        runtime: runtime,
        source: source,
        account_source: account_source
      })

    unit = institution!(f)
    assignment = assignment_input(f, unit)

    assert {:ok, _} =
             Institutions.assign_initial_operator(institution_runtime, context_a(), assignment)

    assert {:ok, _} =
             Institutions.publish_institution(
               institution_runtime,
               context_a(),
               publish_input(unit.id)
             )

    on_exit(fn ->
      if Process.alive?(source), do: Agent.stop(source)
      if Process.alive?(account_source), do: Agent.stop(account_source)
    end)

    {:ok, Map.put(f, :unit, unit)}
  end

  test "student without account and staff overlap use one person; exact reads are minimal", f do
    person = person!(f)
    student = participation!(f, person, :student)
    staff = participation!(f, person, :staff)

    assert {:ok, %{person_id: id, kind: "student"}} =
             Foundation.current_participation(f.runtime, context_a(), student.id)

    assert id == person.id

    assert {:ok, %{display_name: "Synthetic Person"}} =
             Foundation.current_person(f.runtime, context_a(), person.id)

    assert {:error, %Error{code: :not_found}} =
             Foundation.current_staff_account(f.runtime, context_a(), f.membership_a_denied)

    input = account_input(f, person, staff)
    assert {:ok, account} = Foundation.associate_staff_account(f.runtime, context_a(), input)

    assert {:ok, %{id: account_id, person_id: ^id}} =
             Foundation.current_staff_account(f.runtime, context_a(), input.membership_id)

    assert account_id == account.id

    assert {:error, %Error{code: :forbidden}} =
             Foundation.current_person(f.runtime, context_a_denied(), person.id)

    assert [[4, 4, 4]] = facts(f)
  end

  test "private resources expose no collection or raw actions" do
    assert :ok = ResourceContract.validate_domain(Chimwemwe.People)

    for resource <- Ash.Domain.Info.resources(Chimwemwe.People),
        do: assert(Ash.Resource.Info.actions(resource) == [])

    assert {:error, :invalid_runtime} = Runtime.new(self(), String, nil)
  end

  test "unknown input, missing context and independent capabilities fail closed", f do
    assert {:error, _} = Foundation.register_person(f.runtime, nil, person_input())

    assert {:error, %Error{code: :forbidden}} =
             Foundation.register_person(f.runtime, context_a_denied(), person_input())

    for extra <- [
          %{tenant_id: @tenant_b},
          %{role: "teacher"},
          %{date_of_birth: Date.utc_today()},
          %{verified: true}
        ] do
      assert {:error, %Error{code: :invalid_input}} =
               Foundation.register_person(
                 f.runtime,
                 context_a(),
                 Map.merge(person_input(), extra)
               )
    end

    person = person!(f)
    deny(f, "participations.record_staff")

    assert {:error, %Error{code: :forbidden}} =
             Foundation.record_staff_affiliation(
               f.runtime,
               context_a(),
               participation_input(f, person)
             )

    assert {:ok, _} =
             Foundation.record_student_participation(
               f.runtime,
               context_a(),
               participation_input(f, person)
             )
  end

  test "cross-tenant reads and targets are non-disclosing", f do
    person = person!(f)
    staff = participation!(f, person, :staff)

    for id <- [person.id, UUID.generate()] do
      assert {:error, %Error{code: :not_found}} =
               Foundation.current_person(f.runtime, context_b(), id)
    end

    assert {:error, %Error{code: :not_found}} =
             Foundation.current_participation(f.runtime, context_b(), staff.id)

    input = %{account_input(f, person, staff) | membership_id: f.membership_b}

    assert {:error, %Error{code: :not_found}} =
             Foundation.associate_staff_account(f.runtime, context_a(), input)

    assert {:ok, foreign} = Foundation.register_person(f.runtime, context_b(), person_input())

    assert {:error, %Error{code: :not_found}} =
             Foundation.record_student_participation(
               f.runtime,
               context_a(),
               participation_input(f, foreign)
             )
  end

  test "replay is exact and actor/request bound with current authorization", f do
    input = person_input()
    assert {:ok, person} = Foundation.register_person(f.runtime, context_a(), input)
    assert {:ok, ^person} = Foundation.register_person(f.runtime, context_a(), input)

    assert {:error, %Error{code: :idempotency_conflict}} =
             Foundation.register_person(f.runtime, context_a_peer(), input)

    assert {:error, %Error{code: :idempotency_conflict}} =
             Foundation.register_person(f.runtime, context_a(), %{
               input
               | display_name: "Different Synthetic Name"
             })

    deny(f, "persons.register")

    assert {:error, %Error{code: :forbidden}} =
             Foundation.register_person(f.runtime, context_a(), input)

    assert [[1, 1, 1]] = facts(f)
  end

  test "module and institution dependency gates remain independent", f do
    person = person!(f)

    for key <- ["people.core", "institution.structure"] do
      assert {:ok, _} =
               query(
                 f,
                 "UPDATE platform_module_activations a SET state = 'inactive', replay_from_cursor = consumer_cursor, projection_ready = false, reconciliation_required = true, deactivated_at = NOW() FROM platform_module_entitlements e WHERE a.entitlement_id = e.id AND e.tenant_id = $1 AND e.module_key = $2",
                 [dump(@tenant_a), key]
               )

      assert {:error, %Error{code: :module_unavailable}} =
               Foundation.current_person(f.runtime, context_a(), person.id)

      assert {:ok, _} =
               query(
                 f,
                 "UPDATE platform_module_activations a SET state = 'active', replay_from_cursor = NULL, projection_ready = true, reconciliation_required = false, deactivated_at = NULL FROM platform_module_entitlements e WHERE a.entitlement_id = e.id AND e.tenant_id = $1 AND e.module_key = $2",
                 [dump(@tenant_a), key]
               )
    end
  end

  test "name correction preserves person identity and rejects stale changes", f do
    person = person!(f)

    input =
      Map.merge(keys(), %{
        person_id: person.id,
        expected_version: 1,
        display_name: "Corrected Synthetic Name",
        reason: :name_correction
      })

    assert {:ok, revised} = Foundation.revise_person_name(f.runtime, context_a(), input)
    assert revised.id == person.id and revised.lock_version == 2
    assert {:ok, ^revised} = Foundation.revise_person_name(f.runtime, context_a(), input)

    assert {:error, %Error{code: :stale}} =
             Foundation.revise_person_name(f.runtime, context_a(), Map.merge(input, keys()))

    assert {:error, %Error{code: :invalid_input}} =
             Foundation.revise_person_name(f.runtime, context_a(), %{input | reason: :arbitrary})

    assert {:error, %Error{code: :stale}} =
             Foundation.record_staff_affiliation(
               f.runtime,
               context_a(),
               participation_input(f, person)
             )

    assert {:ok, %{display_name: "Corrected Synthetic Name"}} =
             Foundation.current_person(f.runtime, context_a(), person.id)
  end

  test "duplicate names are allowed but duplicate participation is refused", f do
    one = person!(f)
    two = person!(f)
    refute one.id == two.id
    participation!(f, one, :student)

    assert {:error, %Error{code: :conflict}} =
             Foundation.record_student_participation(
               f.runtime,
               context_a(),
               participation_input(f, one)
             )

    assert {:error, %Error{code: :invalid_input}} =
             Foundation.record_staff_affiliation(f.runtime, context_a(), %{
               participation_input(f, two)
               | effective_until: Date.add(Date.utc_today(), -1)
             })

    draft = institution!(f)

    assert {:error, %Error{code: :not_found}} =
             Foundation.record_staff_affiliation(f.runtime, context_a(), %{
               participation_input(f, two)
               | institutional_unit_id: draft.id
             })
  end

  test "unverified, stale, wrong-person and non-human account proofs are refused", f do
    person = person!(f)
    staff = participation!(f, person, :staff)
    input = account_input(f, person, staff)

    for override <- [
          :revoked,
          %{person_id: UUID.generate()},
          %{membership_id: f.membership_b},
          %{person_version: 99},
          %{human_account: false},
          %{matched: false},
          %{policy: "unknown"},
          %{checked_at: DateTime.add(DateTime.utc_now(), -600)},
          %{extra: true}
        ] do
      Agent.update(f.account_source, &%{&1 | overrides: override})

      assert {:error, %Error{code: :evidence_unavailable}} =
               Foundation.associate_staff_account(f.runtime, context_a(), input)
    end

    Agent.update(f.account_source, &%{&1 | records: %{}, overrides: %{}})

    assert {:error, %Error{code: :evidence_unavailable}} =
             Foundation.associate_staff_account(f.runtime, context_a(), input)

    assert [[2, 2, 2]] = facts(f)
  end

  test "account association needs effective staff participation and separate authority", f do
    person = person!(f)
    student = participation!(f, person, :student)

    assert {:error, %Error{code: :conflict}} =
             Foundation.associate_staff_account(
               f.runtime,
               context_a(),
               account_input(f, person, student)
             )

    assert {:ok, future} =
             Foundation.record_staff_affiliation(f.runtime, context_a(), %{
               participation_input(f, person)
               | effective_from: Date.add(Date.utc_today(), 1)
             })

    assert {:error, %Error{code: :conflict}} =
             Foundation.associate_staff_account(
               f.runtime,
               context_a(),
               account_input(f, person, future)
             )

    deny(f, "accounts.associate_staff")

    assert {:error, %Error{code: :forbidden}} =
             Foundation.associate_staff_account(
               f.runtime,
               context_a(),
               account_input(f, person, future)
             )
  end

  test "account revocation is retained, replayable and permits fresh verified relinking", f do
    person = person!(f)
    staff = participation!(f, person, :staff)
    input = account_input(f, person, staff)
    assert {:ok, account} = Foundation.associate_staff_account(f.runtime, context_a(), input)
    assert {:ok, ^account} = Foundation.associate_staff_account(f.runtime, context_a(), input)
    assert Agent.get(f.account_source, & &1.calls) == 1
    revoke = Map.merge(keys(), %{association_id: account.id, expected_version: 1})

    assert {:ok, result} =
             Foundation.revoke_staff_account_association(f.runtime, context_a(), revoke)

    assert {:ok, ^result} =
             Foundation.revoke_staff_account_association(f.runtime, context_a(), revoke)

    assert {:error, %Error{code: :not_found}} =
             Foundation.current_staff_account(f.runtime, context_a(), input.membership_id)

    assert {:ok, replacement} =
             Foundation.associate_staff_account(f.runtime, context_a(), Map.merge(input, keys()))

    refute replacement.id == account.id

    assert {:ok, %{rows: [[2]]}} =
             query(f, "SELECT count(*) FROM people_staff_account_associations")
  end

  test "ending staff today removes current account resolution without deleting history", f do
    person = person!(f)

    assert {:ok, staff} =
             Foundation.record_staff_affiliation(f.runtime, context_a(), %{
               participation_input(f, person)
               | effective_from: Date.add(Date.utc_today(), -2)
             })

    input = account_input(f, person, staff)
    assert {:ok, _} = Foundation.associate_staff_account(f.runtime, context_a(), input)

    ending =
      Map.merge(keys(), %{
        participation_id: staff.id,
        expected_version: 1,
        effective_until: Date.utc_today()
      })

    assert {:ok, ended} = Foundation.end_participation(f.runtime, context_a(), ending)
    assert {:ok, ^ended} = Foundation.end_participation(f.runtime, context_a(), ending)

    assert {:error, %Error{code: :not_found}} =
             Foundation.current_staff_account(f.runtime, context_a(), input.membership_id)

    assert {:error, %Error{code: :stale}} =
             Foundation.end_participation(f.runtime, context_a(), Map.merge(ending, keys()))

    assert {:ok, %{rows: [[1]]}} =
             query(f, "SELECT count(*) FROM people_staff_account_associations")
  end

  test "concurrent registration retries and competing account matches are serialized", f do
    input = person_input()

    results =
      Task.async_stream(1..3, fn _ ->
        Foundation.register_person(f.runtime, context_a(), input)
      end)
      |> Enum.map(fn {:ok, value} -> value end)

    assert [{:ok, person}] = Enum.uniq(results)
    another = person!(f)
    staff_one = participation!(f, person, :staff)
    staff_two = participation!(f, another, :staff)
    inputs = [account_input(f, person, staff_one), account_input(f, another, staff_two)]

    results =
      Task.async_stream(inputs, &Foundation.associate_staff_account(f.runtime, context_a(), &1))
      |> Enum.map(fn {:ok, value} -> value end)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &match?({:error, %Error{code: :conflict}}, &1)) == 1
  end

  test "failure after outbox insertion rolls back the account and all action evidence", f do
    person = person!(f)
    staff = participation!(f, person, :staff)
    input = account_input(f, person, staff)
    install_completion_failure(f.persistence)

    try do
      assert {:error, _} = Foundation.associate_staff_account(f.runtime, context_a(), input)
      assert [[2, 2, 2]] = facts(f)

      assert {:ok, %{rows: [[0]]}} =
               query(f, "SELECT count(*) FROM people_staff_account_associations")
    after
      remove_completion_failure(f.persistence)
    end

    assert {:ok, _} = Foundation.associate_staff_account(f.runtime, context_a(), input)
  end

  test "database rejects person identity changes, invalid proof, cross-tenant and record deletion",
       f do
    person = person!(f)
    staff = participation!(f, person, :staff)

    assert {:error, %Postgrex.Error{}} =
             query(f, "UPDATE people_persons SET tenant_id = $2 WHERE id = $1", [
               dump(person.id),
               dump(@tenant_b)
             ])

    assert {:error, %Postgrex.Error{}} =
             query(f, "DELETE FROM people_participations WHERE id = $1", [dump(staff.id)])

    assert {:error, %Postgrex.Error{}} =
             query(
               f,
               "INSERT INTO people_staff_account_associations (id, tenant_id, person_id, participation_id, membership_id, evidence_reference, verification, lock_version, inserted_at) VALUES ($1,$2,$3,$4,$5,$6,'{}',1,NOW())",
               Enum.map(
                 [
                   UUID.generate(),
                   @tenant_a,
                   person.id,
                   staff.id,
                   f.membership_a_denied,
                   UUID.generate()
                 ],
                 &dump/1
               )
             )

    assert {:error, %Postgrex.Error{}} =
             query(
               f,
               "INSERT INTO people_participations (id, tenant_id, person_id, institutional_unit_id, kind, effective_from, source_reference, lock_version, inserted_at) VALUES ($1,$2,$3,$4,'student',CURRENT_DATE,$5,1,NOW())",
               Enum.map(
                 [UUID.generate(), @tenant_b, person.id, f.unit.id, UUID.generate()],
                 &dump/1
               )
             )
  end

  test "events are Restricted and contain only stable IDs and versions", f do
    person = person!(f)

    assert {:ok, %{rows: [["restricted", payload]]}} =
             query(
               f,
               "SELECT classification, payload FROM platform_outbox_events WHERE id = $1",
               [dump(person.event_id)]
             )

    assert payload == %{"id" => person.id, "lock_version" => 1}
    refute inspect(payload) =~ "Synthetic Person"
  end

  test "each action and read rejects absent context and an unprivileged actor", f do
    person = person!(f)
    staff = participation!(f, person, :staff)
    link_input = account_input(f, person, staff)
    assert {:ok, link} = Foundation.associate_staff_account(f.runtime, context_a(), link_input)

    calls = [
      {:register_person, person_input()},
      {:revise_person_name,
       Map.merge(keys(), %{
         person_id: person.id,
         expected_version: 1,
         display_name: "Another Synthetic Name",
         reason: :name_correction
       })},
      {:record_student_participation, participation_input(f, person)},
      {:record_staff_affiliation, participation_input(f, person)},
      {:end_participation,
       Map.merge(keys(), %{
         participation_id: staff.id,
         expected_version: 1,
         effective_until: Date.add(Date.utc_today(), 1)
       })},
      {:associate_staff_account, Map.merge(link_input, keys())},
      {:revoke_staff_account_association,
       Map.merge(keys(), %{association_id: link.id, expected_version: 1})},
      {:current_person, person.id},
      {:current_participation, staff.id},
      {:current_staff_account, link_input.membership_id}
    ]

    for {action, input} <- calls do
      assert {:error, _} = apply(Foundation, action, [f.runtime, nil, input])

      assert {:error, %Error{code: :forbidden}} =
               apply(Foundation, action, [f.runtime, context_a_denied(), input])
    end

    assert [[3, 3, 3]] = facts(f)
  end

  test "Restricted events cannot be downgraded or claimed by the Internal-only dispatcher", f do
    person = person!(f)

    assert {:error, %Postgrex.Error{}} =
             query(
               f,
               "UPDATE platform_outbox_events SET classification = 'internal' WHERE id = $1",
               [dump(person.event_id)]
             )

    assert {:ok, :granted} =
             Persistence.with_writer(f.persistence, context_a(), fn ->
               capability = UUID.generate()
               insert_capability(capability, @tenant_a, "platform.outbox.dispatch")
               insert_grant(@tenant_a, f.role_a, capability)
               :granted
             end)

    assert {:ok, registry} =
             ConsumerRegistry.new([
               %{
                 key: "people.synthetic.internal_sink",
                 events: [%{type: "people.core.persons.register.completed", schema_versions: [1]}],
                 handler: Chimwemwe.Test.OutboxConsumer,
                 handler_revision: 1,
                 batch_size: 2,
                 lease_ms: 60_000,
                 max_attempts: 3,
                 retry_ms: 1_000
               }
             ])

    assert {:ok, []} =
             Outbox.claim(
               f.persistence,
               registry,
               context_a(),
               "people.synthetic.internal_sink"
             )

    assert {:ok, %{rows: [[0]]}} =
             query(f, "SELECT count(*) FROM platform_outbox_deliveries WHERE event_id = $1", [
               dump(person.event_id)
             ])
  end

  test "exclusive end and prospective ending rules prevent current staff matches", f do
    person = person!(f)

    input = %{
      participation_input(f, person)
      | effective_from: Date.add(Date.utc_today(), -2),
        effective_until: Date.utc_today()
    }

    assert {:ok, staff} = Foundation.record_staff_affiliation(f.runtime, context_a(), input)

    assert {:error, %Error{code: :conflict}} =
             Foundation.associate_staff_account(
               f.runtime,
               context_a(),
               account_input(f, person, staff)
             )

    assert {:error, %Error{code: :conflict}} =
             Foundation.end_participation(
               f.runtime,
               context_a(),
               Map.merge(keys(), %{
                 participation_id: staff.id,
                 expected_version: 1,
                 effective_until: Date.add(Date.utc_today(), 1)
               })
             )

    other = person!(f)

    assert {:ok, open} =
             Foundation.record_staff_affiliation(f.runtime, context_a(), %{
               participation_input(f, other)
               | effective_from: Date.add(Date.utc_today(), -2)
             })

    assert {:error, %Error{code: :invalid_input}} =
             Foundation.end_participation(
               f.runtime,
               context_a(),
               Map.merge(keys(), %{
                 participation_id: open.id,
                 expected_version: 1,
                 effective_until: Date.add(Date.utc_today(), -1)
               })
             )
  end

  test "staff account uses the institution-local date rather than UTC", f do
    assert {:ok, unit} =
             Institutions.register_institution(f.institution_runtime, context_a(), %{
               register_input()
               | time_zone: "Pacific/Kiritimati"
             })

    assert {:ok, %{rows: [[local_day]]}} =
             query(f, "SELECT (statement_timestamp() AT TIME ZONE 'Pacific/Kiritimati')::date")

    assignment = %{assignment_input(f, unit) | effective_from: local_day}

    assert {:ok, _} =
             Institutions.assign_initial_operator(f.institution_runtime, context_a(), assignment)

    assert {:ok, _} =
             Institutions.publish_institution(
               f.institution_runtime,
               context_a(),
               publish_input(unit.id)
             )

    person = person!(f)

    assert {:ok, staff} =
             Foundation.record_staff_affiliation(f.runtime, context_a(), %{
               participation_input(f, person)
               | institutional_unit_id: unit.id,
                 effective_from: local_day
             })

    input = account_input(f, person, staff)
    assert {:ok, _} = Foundation.associate_staff_account(f.runtime, context_a(), input)

    assert {:ok, %{person_id: id}} =
             Foundation.current_staff_account(f.runtime, context_a(), input.membership_id)

    assert id == person.id
  end

  test "recorded timestamps stay UTC even when the database session uses another zone", f do
    assert {:ok, {:ok, :verified}} =
             Persistence.with_writer(f.persistence, context_a(), fn ->
               Repo.transaction(fn ->
                 Repo.query!("SET LOCAL TIME ZONE 'Pacific/Kiritimati'")
                 person = person!(f)
                 staff = participation!(f, person, :staff)

                 assert {:ok, account} =
                          Foundation.associate_staff_account(
                            f.runtime,
                            context_a(),
                            account_input(f, person, staff)
                          )

                 assert {:ok, _} =
                          Foundation.revoke_staff_account_association(
                            f.runtime,
                            context_a(),
                            Map.merge(keys(), %{association_id: account.id, expected_version: 1})
                          )

                 assert %{rows: [[true, true, true, true]]} =
                          Repo.query!(
                            """
                            SELECT abs(extract(epoch from (n.inserted_at - (statement_timestamp() AT TIME ZONE 'UTC')))) < 5,
                                   abs(extract(epoch from (p.inserted_at - (statement_timestamp() AT TIME ZONE 'UTC')))) < 5,
                                   abs(extract(epoch from (a.inserted_at - (statement_timestamp() AT TIME ZONE 'UTC')))) < 5,
                                   abs(extract(epoch from (a.revoked_at - (statement_timestamp() AT TIME ZONE 'UTC')))) < 5
                            FROM people_persons n JOIN people_participations p ON p.person_id = n.id AND p.tenant_id = n.tenant_id
                            JOIN people_staff_account_associations a ON a.participation_id = p.id AND a.tenant_id = p.tenant_id
                            WHERE n.id = $1 AND n.tenant_id = $2
                            """,
                            [dump(person.id), dump(@tenant_a)]
                          )

                 :verified
               end)
             end)
  end

  defp keys, do: %{idempotency_key: UUID.generate(), causation_id: UUID.generate()}
  defp person_input, do: Map.put(keys(), :display_name, "Synthetic Person")

  defp person!(f) do
    assert {:ok, person} = Foundation.register_person(f.runtime, context_a(), person_input())
    person
  end

  defp participation_input(f, person),
    do:
      Map.merge(keys(), %{
        person_id: person.id,
        expected_person_version: person.lock_version,
        institutional_unit_id: f.unit.id,
        effective_from: Date.utc_today(),
        effective_until: nil,
        source_reference: UUID.generate()
      })

  defp participation!(f, person, kind) do
    action = if kind == :staff, do: :record_staff_affiliation, else: :record_student_participation

    assert {:ok, part} =
             apply(Foundation, action, [f.runtime, context_a(), participation_input(f, person)])

    part
  end

  defp account_input(f, person, part) do
    evidence = UUID.generate()

    binding = %{
      tenant_id: @tenant_a,
      person_id: person.id,
      participation_id: part.id,
      membership_id: f.membership_a_denied,
      actor_id: @actor_a_denied
    }

    Agent.update(f.account_source, &put_in(&1, [:records, evidence], binding))

    Map.merge(keys(), %{
      participation_id: part.id,
      expected_version: part.lock_version,
      expected_person_version: person.lock_version,
      membership_id: f.membership_a_denied,
      evidence_reference: evidence
    })
  end

  defp deny(f, capability) do
    assert {:ok, _} =
             query(
               f,
               "DELETE FROM platform_role_capability_grants g USING platform_capabilities c WHERE g.capability_id = c.id AND g.tenant_id = c.tenant_id AND c.tenant_id = $1 AND c.key = $2",
               [dump(@tenant_a), "people.core." <> capability]
             )
  end

  defp register_input do
    %{
      display_name: "Synthetic Learning Institution",
      time_zone: "Etc/UTC",
      idempotency_key: UUID.generate(),
      causation_id: UUID.generate()
    }
  end

  defp institution!(f) do
    assert {:ok, unit} =
             Institutions.register_institution(
               f.institution_runtime,
               context_a(),
               register_input()
             )

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
        "SELECT (SELECT count(*) FROM platform_authority_audit_events WHERE action_name LIKE 'people.core.%'), (SELECT count(*) FROM platform_outbox_events WHERE aggregate_type LIKE 'people.core.%'), (SELECT count(*) FROM platform_authority_action_idempotency WHERE action_name LIKE 'people.core.%')"
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

               for key <- @people_capabilities do
                 id = UUID.generate()
                 insert_capability(id, tenant_id, "people.core." <> key)
                 insert_grant(tenant_id, role_id, id)
               end

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
      VALUES ($1, $2, 'Synthetic people administrator', 1, NOW(), NOW())
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
    for {key, version} <- [
          {"organization.legal", "1.2.0"},
          {"institution.structure", "1.0.0"},
          {"people.core", "1.0.0"}
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

  defp install_completion_failure(runtime) do
    assert {:ok, :installed} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_people_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_people_completion()")

               Repo.query!("""
               CREATE FUNCTION test_fail_people_completion()
               RETURNS trigger
               LANGUAGE plpgsql
               AS $$
               BEGIN
                 IF NEW.status = 'completed' AND
                    NEW.action_name LIKE 'people.core.%' THEN
                   RAISE EXCEPTION USING
                     ERRCODE = '40001',
                     MESSAGE = 'synthetic legal entity completion failure';
                 END IF;

                 RETURN NEW;
               END;
               $$;
               """)

               Repo.query!("""
               CREATE TRIGGER test_fail_people_completion
               BEFORE UPDATE OF status
               ON platform_authority_action_idempotency
               FOR EACH ROW
               EXECUTE FUNCTION test_fail_people_completion();
               """)

               :installed
             end)
  end

  defp remove_completion_failure(runtime) do
    assert {:ok, :removed} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_people_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_people_completion()")
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
