defmodule Chimwemwe.Classroom.FoundationTest do
  use ExUnit.Case, async: false
  alias Chimwemwe.Classroom.{Error, Foundation}
  alias Chimwemwe.InstitutionalStructure.Foundation, as: Institutions
  alias Chimwemwe.OrganizationLegal.Foundation, as: LegalFoundation
  alias Chimwemwe.People.Foundation, as: People
  alias Chimwemwe.People.{Runtime, TestVerifier}

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

    f = Map.put(f, :unit, unit)
    calendar = calendar!(f)
    student = participation!(f, person!(f), :student)
    staff = participation!(f, person!(f), :staff)
    {:ok, Map.merge(f, %{calendar: calendar, student: student, staff: staff})}
  end

  test "separate class, year enrolment, teaching and placement commit restricted evidence", f do
    {class, enrolment, assignment, placement} = classroom!(f)

    assert {:ok, %{id: id, calendar_revision: revision}} =
             Foundation.current_class(f.persistence, context_a(), class.id)

    assert id == class.id and revision == f.calendar.revision

    assert {:ok, %{participation_id: student}} =
             Foundation.current_enrolment(f.persistence, context_a(), enrolment.id)

    assert student == f.student.id

    assert {:ok, %{participation_id: staff}} =
             Foundation.current_teaching_assignment(f.persistence, context_a(), assignment.id)

    assert staff == f.staff.id

    assert {:ok, %{enrolment_id: enrolled, effective_until: until}} =
             Foundation.current_placement(f.persistence, context_a(), placement.id)

    assert enrolled == enrolment.id and until == Date.add(Date.utc_today(), 100)
    assert [[4, 4, 4]] = facts(f)

    assert {:ok, %{rows: [[0]]}} =
             query(f, "SELECT count(*) FROM people_staff_account_associations")

    assert {:ok, %{rows: rows}} =
             query(
               f,
               "SELECT classification, payload FROM platform_outbox_events WHERE aggregate_type LIKE 'classroom.core.%'"
             )

    assert length(rows) == 4

    for [classification, payload] <- rows do
      assert classification == "restricted"
      assert Enum.sort(Map.keys(payload)) == ["id", "lock_version"]
    end
  end

  test "private resources expose no raw actions or collection", _f do
    assert :ok = ResourceContract.validate_domain(Chimwemwe.Classroom)

    for resource <- Ash.Domain.Info.resources(Chimwemwe.Classroom),
        do: assert(Ash.Resource.Info.actions(resource) == [])
  end

  test "every operation and exact read requires context and independent permission", f do
    {class, enrolment, assignment, placement} = classroom!(f)

    mutations = [
      {:create_class, class_input(f)},
      {:enrol_student, enrol_input(f)},
      {:assign_teacher, teacher_input(f, class)},
      {:place_student, placement_input(enrolment, class)},
      {:end_enrolment, ending(:enrolment_id, enrolment.id)},
      {:end_teaching_assignment, ending(:assignment_id, assignment.id)},
      {:end_placement, ending(:placement_id, placement.id)}
    ]

    for {action, input} <- mutations do
      assert {:error, _} = apply(Foundation, action, [f.persistence, nil, input])

      assert {:error, %Error{code: :forbidden}} =
               apply(Foundation, action, [f.persistence, context_a_denied(), input])
    end

    for {action, id} <- [
          {:current_class, class.id},
          {:current_enrolment, enrolment.id},
          {:current_teaching_assignment, assignment.id},
          {:current_placement, placement.id}
        ] do
      assert {:error, _} = apply(Foundation, action, [f.persistence, nil, id])

      assert {:error, %Error{code: :forbidden}} =
               apply(Foundation, action, [f.persistence, context_a_denied(), id])

      assert {:error, %Error{code: :not_found}} =
               apply(Foundation, action, [f.persistence, context_b(), id])

      assert {:error, %Error{code: :not_found}} =
               apply(Foundation, action, [f.persistence, context_b(), UUID.generate()])
    end

    deny(f, "placements.record")

    assert {:error, %Error{code: :forbidden}} =
             Foundation.place_student(
               f.persistence,
               context_a(),
               placement_input(enrolment, class)
             )

    assert [[4, 4, 4]] = facts(f)
  end

  test "calendar selection rejects draft, wrong revision, forged owner and cross tenant", f do
    input = class_input(f)
    draft = calendar!(f, "draft")

    for changed <- [
          %{calendar_revision: String.duplicate("f", 64)},
          %{calendar_id: UUID.generate()},
          %{institutional_unit_id: UUID.generate()},
          %{academic_year_id: draft.year_id, calendar_id: draft.id}
        ] do
      assert {:error, %Error{code: code}} =
               Foundation.create_class(f.persistence, context_a(), Map.merge(input, changed))

      assert code in [:conflict, :not_found]
    end

    assert {:error, %Error{code: :not_found}} =
             Foundation.create_class(f.persistence, context_b(), input)

    for extra <- [
          %{tenant_id: @tenant_b},
          %{role: "teacher"},
          %{current_year: true},
          %{placement: "other"}
        ] do
      assert {:error, %Error{code: :invalid_input}} =
               Foundation.create_class(f.persistence, context_a(), Map.merge(input, extra))
    end

    assert [[0, 0, 0]] = facts(f)
  end

  test "date, kind, stale version and year compatibility reject without partial facts", f do
    class = class!(f)
    enrolment = enrolment!(f)

    assert {:error, %Error{code: :conflict}} =
             Foundation.enrol_student(f.persistence, context_a(), %{
               enrol_input(f)
               | participation_id: f.staff.id
             })

    assert {:error, %Error{code: :conflict}} =
             Foundation.assign_teacher(f.persistence, context_a(), %{
               teacher_input(f, class)
               | participation_id: f.student.id
             })

    assert {:error, %Error{code: :stale}} =
             Foundation.place_student(f.persistence, context_a(), %{
               placement_input(enrolment, class)
               | expected_enrolment_version: 9
             })

    assert {:error, %Error{code: :stale}} =
             Foundation.assign_teacher(f.persistence, context_a(), %{
               teacher_input(f, class)
               | expected_participation_version: 9
             })

    assert {:error, %Error{code: :conflict}} =
             Foundation.place_student(f.persistence, context_a(), %{
               placement_input(enrolment, class)
               | effective_until: Date.add(Date.utc_today(), 401)
             })

    assert {:error, %Error{code: :invalid_input}} =
             Foundation.place_student(f.persistence, context_a(), %{
               placement_input(enrolment, class)
               | effective_until: Date.utc_today()
             })

    another = Map.put(f, :calendar, calendar!(f)) |> class!()

    assert {:error, %Error{code: :conflict}} =
             Foundation.place_student(
               f.persistence,
               context_a(),
               placement_input(enrolment, another)
             )

    assert [[3, 3, 3]] = facts(f)
  end

  test "move ends first placement and preserves adjacent class intervals", f do
    first = class!(f)
    second = class!(f)
    enrolment = enrolment!(f)
    input = placement_input(enrolment, first)
    assert {:ok, placed} = Foundation.place_student(f.persistence, context_a(), input)

    assert {:error, %Error{code: :conflict}} =
             Foundation.place_student(
               f.persistence,
               context_a(),
               placement_input(enrolment, second)
             )

    assert {:ok, %{lock_version: 2}} =
             Foundation.end_placement(
               f.persistence,
               context_a(),
               ending(:placement_id, placed.id)
             )

    replacement = %{
      placement_input(enrolment, second)
      | effective_from: Date.add(Date.utc_today(), 30)
    }

    assert {:ok, _} = Foundation.place_student(f.persistence, context_a(), replacement)

    assert {:ok, %{effective_until: end_date, lock_version: 2}} =
             Foundation.current_placement(f.persistence, context_a(), placed.id)

    assert end_date == replacement.effective_from

    assert {:error, %Error{code: :stale}} =
             Foundation.end_placement(
               f.persistence,
               context_a(),
               ending(:placement_id, placed.id)
             )

    assert {:error, %Error{code: :conflict}} =
             Foundation.end_placement(f.persistence, context_a(), %{
               ending(:placement_id, placed.id)
               | expected_version: 2
             })
  end

  test "shorten children before parents; ending is prospective and retains history", f do
    {_class, enrolment, assignment, placement} = classroom!(f)

    assert {:error, %Error{code: :conflict}} =
             Foundation.end_enrolment(
               f.persistence,
               context_a(),
               ending(:enrolment_id, enrolment.id)
             )

    assert {:error, _} =
             People.end_participation(
               f.runtime,
               context_a(),
               Map.merge(keys(), %{
                 participation_id: f.student.id,
                 expected_version: 1,
                 effective_until: Date.add(Date.utc_today(), 30)
               })
             )

    assert {:error, %Error{code: :conflict}} =
             Foundation.end_placement(f.persistence, context_a(), %{
               ending(:placement_id, placement.id)
               | effective_until: Date.add(Date.utc_today(), -1)
             })

    assert {:ok, _} =
             Foundation.end_placement(
               f.persistence,
               context_a(),
               ending(:placement_id, placement.id)
             )

    assert {:ok, _} =
             Foundation.end_enrolment(
               f.persistence,
               context_a(),
               ending(:enrolment_id, enrolment.id)
             )

    assert {:ok, _} =
             People.end_participation(
               f.runtime,
               context_a(),
               Map.merge(keys(), %{
                 participation_id: f.student.id,
                 expected_version: 1,
                 effective_until: Date.add(Date.utc_today(), 30)
               })
             )

    assert {:error, _} =
             People.end_participation(
               f.runtime,
               context_a(),
               Map.merge(keys(), %{
                 participation_id: f.staff.id,
                 expected_version: 1,
                 effective_until: Date.add(Date.utc_today(), 30)
               })
             )

    assert {:ok, _} =
             Foundation.end_teaching_assignment(
               f.persistence,
               context_a(),
               ending(:assignment_id, assignment.id)
             )

    assert {:ok, _} =
             People.end_participation(
               f.runtime,
               context_a(),
               Map.merge(keys(), %{
                 participation_id: f.staff.id,
                 expected_version: 1,
                 effective_until: Date.add(Date.utc_today(), 30)
               })
             )

    assert {:ok, %{lock_version: 2}} =
             Foundation.current_enrolment(f.persistence, context_a(), enrolment.id)
  end

  test "overlapping teaching fails but adjacent assignment and multiple teachers work", f do
    class = class!(f)
    input = teacher_input(f, class)
    assert {:ok, _} = Foundation.assign_teacher(f.persistence, context_a(), input)

    assert {:error, %Error{code: :conflict}} =
             Foundation.assign_teacher(f.persistence, context_a(), Map.merge(input, keys()))

    assert {:ok, _} =
             Foundation.assign_teacher(f.persistence, context_a(), %{
               teacher_input(f, class)
               | effective_from: input.effective_until,
                 effective_until: Date.add(input.effective_until, 10)
             })

    staff = participation!(f, person!(f), :staff)

    assert {:ok, _} =
             Foundation.assign_teacher(f.persistence, context_a(), %{
               teacher_input(f, class)
               | participation_id: staff.id
             })
  end

  test "exact retry is actor bound, conflict checked and reauthorizes", f do
    input = class_input(f)
    assert {:ok, result} = Foundation.create_class(f.persistence, context_a(), input)
    assert {:ok, ^result} = Foundation.create_class(f.persistence, context_a(), input)

    assert {:error, %Error{code: :idempotency_conflict}} =
             Foundation.create_class(f.persistence, context_a_peer(), input)

    assert {:error, %Error{code: :idempotency_conflict}} =
             Foundation.create_class(f.persistence, context_a(), %{input | label: "Changed"})

    deny(f, "classes.create")

    assert {:error, %Error{code: :forbidden}} =
             Foundation.create_class(f.persistence, context_a(), input)

    assert [[1, 1, 1]] = facts(f)
  end

  test "concurrent retries produce one receipt and competing placements cannot overlap", f do
    input = class_input(f)

    results =
      1..2
      |> Task.async_stream(fn _ -> Foundation.create_class(f.persistence, context_a(), input) end,
        max_concurrency: 2
      )
      |> Enum.map(fn {:ok, result} -> result end)

    assert [{:ok, class}, {:ok, retry}] = results
    assert retry == class
    enrolment = enrolment!(f)

    results =
      1..2
      |> Task.async_stream(
        fn _ ->
          Foundation.place_student(f.persistence, context_a(), placement_input(enrolment, class))
        end,
        max_concurrency: 2
      )
      |> Enum.map(fn {:ok, result} -> result end)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &match?({:error, %Error{code: :conflict}}, &1)) == 1
    assert [[3, 3, 3]] = facts(f)
  end

  test "failure after outbox rolls back state audit event and idempotency", f do
    install_completion_failure(f.persistence)

    try do
      assert {:error, %Error{code: :retryable_dependency}} =
               Foundation.create_class(f.persistence, context_a(), class_input(f))

      assert [[0, 0, 0]] = facts(f)
      assert {:ok, %{rows: [[0]]}} = query(f, "SELECT count(*) FROM classroom_classes")
    after
      remove_completion_failure(f.persistence)
    end

    assert {:ok, _} = Foundation.create_class(f.persistence, context_a(), class_input(f))
  end

  test "module dependencies gate mutations reads and retries", f do
    input = class_input(f)
    assert {:ok, class} = Foundation.create_class(f.persistence, context_a(), input)

    assert {:ok, _} =
             query(
               f,
               "DELETE FROM platform_module_activations a USING platform_module_entitlements e WHERE a.entitlement_id = e.id AND a.tenant_id = e.tenant_id AND e.tenant_id = $1 AND e.module_key = 'academics.calendar'",
               [dump(@tenant_a)]
             )

    assert {:error, %Error{code: :module_unavailable}} =
             Foundation.create_class(f.persistence, context_a(), input)

    assert {:error, %Error{code: :module_unavailable}} =
             Foundation.current_class(f.persistence, context_a(), class.id)
  end

  test "direct writes cannot change identities, delete history or duplicate overlapping placement",
       f do
    {class, enrolment, _assignment, placement} = classroom!(f)

    for {sql, args} <- [
          {"UPDATE classroom_classes SET label = 'Changed' WHERE id = $1", [dump(class.id)]},
          {"DELETE FROM classroom_placements WHERE id = $1", [dump(placement.id)]},
          {"UPDATE classroom_enrolments SET effective_until = effective_until + 1, lock_version = 2 WHERE id = $1",
           [dump(enrolment.id)]},
          {"UPDATE classroom_placements SET effective_from = effective_from + 1, lock_version = 2 WHERE id = $1",
           [dump(placement.id)]},
          {"INSERT INTO classroom_placements (id, tenant_id, enrolment_id, class_id, effective_from, effective_until, lock_version, inserted_at) SELECT $2, tenant_id, enrolment_id, class_id, effective_from, effective_until, 1, inserted_at FROM classroom_placements WHERE id = $1",
           [dump(placement.id), dump(UUID.generate())]}
        ] do
      assert {:error, %Postgrex.Error{postgres: %{code: :check_violation}}} = query(f, sql, args)
    end

    assert [[4, 4, 4]] = facts(f)
  end

  test "Restricted classroom facts cannot be downgraded or delivered by Internal dispatcher", f do
    class = class!(f)

    assert {:error, %Postgrex.Error{}} =
             query(
               f,
               "UPDATE platform_outbox_events SET classification = 'internal' WHERE id = $1",
               [dump(class.event_id)]
             )

    assert {:ok, :granted} =
             Persistence.with_writer(f.persistence, context_a(), fn ->
               id = UUID.generate()
               insert_capability(id, @tenant_a, "platform.outbox.dispatch")
               insert_grant(@tenant_a, f.role_a, id)
               :granted
             end)

    assert {:ok, registry} =
             ConsumerRegistry.new([
               %{
                 key: "classroom.synthetic.internal_sink",
                 events: [
                   %{type: "classroom.core.classes.create.completed", schema_versions: [1]}
                 ],
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
               "classroom.synthetic.internal_sink"
             )

    assert {:ok, %{rows: [[0]]}} =
             query(f, "SELECT count(*) FROM platform_outbox_deliveries WHERE event_id = $1", [
               dump(class.event_id)
             ])
  end

  test "same-tenant different institution is not valid enrolment or teaching scope", f do
    unit = institution!(f)

    assert {:ok, _} =
             Institutions.assign_initial_operator(
               f.institution_runtime,
               context_a(),
               assignment_input(f, unit)
             )

    assert {:ok, _} =
             Institutions.publish_institution(
               f.institution_runtime,
               context_a(),
               publish_input(unit.id)
             )

    other = %{f | unit: unit}
    other = %{other | calendar: calendar!(other)}
    class = class!(other)

    assert {:error, %Error{code: :conflict}} =
             Foundation.enrol_student(f.persistence, context_a(), enrol_input(other))

    assert {:error, %Error{code: :conflict}} =
             Foundation.assign_teacher(f.persistence, context_a(), teacher_input(f, class))

    assert [[1, 1, 1]] = facts(f)
  end

  test "cross-tenant mutation targets fail without creating evidence", f do
    {class, enrolment, assignment, placement} = classroom!(f)

    for {action, input} <- [
          {:enrol_student, enrol_input(f)},
          {:assign_teacher, teacher_input(f, class)},
          {:place_student, placement_input(enrolment, class)},
          {:end_enrolment, ending(:enrolment_id, enrolment.id)},
          {:end_teaching_assignment, ending(:assignment_id, assignment.id)},
          {:end_placement, ending(:placement_id, placement.id)}
        ] do
      assert {:error, %Error{code: :not_found}} =
               apply(Foundation, action, [f.persistence, context_b(), input])
    end

    assert [[4, 4, 4]] = facts(f)
  end

  test "concurrent child placement and enrolment ending cannot leave an invalid interval", f do
    class = class!(f)
    enrolment = enrolment!(f)

    results =
      [
        fn ->
          Foundation.place_student(f.persistence, context_a(), placement_input(enrolment, class))
        end,
        fn ->
          Foundation.end_enrolment(
            f.persistence,
            context_a(),
            ending(:enrolment_id, enrolment.id)
          )
        end
      ]
      |> Task.async_stream(fn work -> work.() end, max_concurrency: 2)
      |> Enum.map(fn {:ok, result} -> result end)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &match?({:error, %Error{}}, &1)) == 1

    assert {:ok, %{rows: [[0]]}} =
             query(
               f,
               "SELECT count(*) FROM classroom_placements p JOIN classroom_enrolments e ON e.id = p.enrolment_id AND e.tenant_id = p.tenant_id WHERE p.effective_until > e.effective_until"
             )
  end

  test "ending follows the pinned year timezone and timestamps remain UTC", f do
    assert {:ok, %{rows: zones}} =
             query(
               f,
               "SELECT name, (statement_timestamp() AT TIME ZONE name)::date FROM (VALUES ('Pacific/Kiritimati'), ('Pacific/Pago_Pago')) AS zones(name)"
             )

    [zone, local_day] = Enum.find(zones, fn [_zone, day] -> day != Date.utc_today() end)
    start_on = Date.add(Date.utc_today(), -4)
    calendar = calendar!(f, "published", start_on: start_on, time_zone: zone)
    scoped = %{f | calendar: calendar}
    person = person!(f)

    assert {:ok, staff} =
             People.record_staff_affiliation(f.runtime, context_a(), %{
               participation_input(f, person)
               | effective_from: start_on
             })

    class = class!(scoped)

    assert {:ok, assignment} =
             Foundation.assign_teacher(f.persistence, context_a(), %{
               teacher_input(f, class)
               | participation_id: staff.id,
                 effective_from: start_on
             })

    assert {:error, %Error{code: :conflict}} =
             Foundation.end_teaching_assignment(f.persistence, context_a(), %{
               ending(:assignment_id, assignment.id)
               | effective_until: Date.add(local_day, -1)
             })

    assert {:ok, {:ok, :verified}} =
             Persistence.with_writer(f.persistence, context_a(), fn ->
               Repo.transaction(fn ->
                 Repo.query!("SET LOCAL TIME ZONE 'Pacific/Kiritimati'")

                 assert {:ok, _} =
                          Foundation.end_teaching_assignment(f.persistence, context_a(), %{
                            ending(:assignment_id, assignment.id)
                            | effective_until: local_day
                          })

                 assert {:ok, created} =
                          Foundation.create_class(f.persistence, context_a(), class_input(scoped))

                 assert %{rows: [[true]]} =
                          Repo.query!(
                            "SELECT abs(extract(epoch from (inserted_at - (statement_timestamp() AT TIME ZONE 'UTC')))) < 5 FROM classroom_classes WHERE id = $1 AND tenant_id = $2",
                            [dump(created.id), dump(@tenant_a)]
                          )

                 :verified
               end)
             end)
  end

  test "unsupported transaction snapshots cannot bypass parent-lock invariants", f do
    assert {:ok, {:error, :rollback}} =
             Persistence.with_writer(f.persistence, context_a(), fn ->
               Repo.transaction(fn ->
                 Repo.query!("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ")

                 assert {:error, %Error{code: :conflict}} =
                          Foundation.create_class(f.persistence, context_a(), class_input(f))
               end)
             end)

    assert [[0, 0, 0]] = facts(f)
  end

  defp classroom!(f) do
    class = class!(f)
    enrolment = enrolment!(f)

    assert {:ok, assignment} =
             Foundation.assign_teacher(f.persistence, context_a(), teacher_input(f, class))

    assert {:ok, placement} =
             Foundation.place_student(
               f.persistence,
               context_a(),
               placement_input(enrolment, class)
             )

    {class, enrolment, assignment, placement}
  end

  defp class!(f) do
    assert {:ok, class} = Foundation.create_class(f.persistence, context_a(), class_input(f))
    class
  end

  defp enrolment!(f) do
    assert {:ok, enrolment} = Foundation.enrol_student(f.persistence, context_a(), enrol_input(f))
    enrolment
  end

  defp class_input(f),
    do:
      Map.merge(keys(), %{
        institutional_unit_id: f.unit.id,
        calendar_id: f.calendar.id,
        academic_year_id: f.calendar.year_id,
        calendar_revision: f.calendar.revision,
        code: "class_" <> String.replace(UUID.generate(), "-", ""),
        label: "Synthetic class"
      })

  defp enrol_input(f),
    do:
      Map.merge(keys(), %{
        participation_id: f.student.id,
        expected_participation_version: 1,
        academic_year_id: f.calendar.year_id,
        calendar_revision: f.calendar.revision,
        effective_from: Date.utc_today(),
        effective_until: Date.add(Date.utc_today(), 200)
      })

  defp teacher_input(f, class),
    do:
      Map.merge(keys(), %{
        participation_id: f.staff.id,
        expected_participation_version: 1,
        class_id: class.id,
        expected_class_version: 1,
        effective_from: Date.utc_today(),
        effective_until: Date.add(Date.utc_today(), 100)
      })

  defp placement_input(enrolment, class),
    do:
      Map.merge(keys(), %{
        enrolment_id: enrolment.id,
        expected_enrolment_version: 1,
        class_id: class.id,
        expected_class_version: 1,
        effective_from: Date.utc_today(),
        effective_until: Date.add(Date.utc_today(), 100)
      })

  defp ending(key, id),
    do:
      Map.merge(keys(), %{
        key => id,
        :expected_version => 1,
        :effective_until => Date.add(Date.utc_today(), 30)
      })

  # Exercise the calendar agent's real named writer, using only synthetic records.
  defp calendar!(f, status \\ "published", options \\ []) do
    alias Chimwemwe.AcademicCalendar.Foundation, as: Calendar
    {:ok, runtime} = Chimwemwe.AcademicCalendar.Runtime.new(f.persistence)

    assert {:ok, calendar} =
             Calendar.register_academic_calendar(
               runtime,
               context_a(),
               Map.merge(keys(), %{
                 institutional_unit_id: f.unit.id,
                 code: "calendar_" <> String.replace(UUID.generate(), "-", "")
               })
             )

    year_id = UUID.generate()
    start_on = Keyword.get(options, :start_on, Date.utc_today())

    definition =
      Map.merge(keys(), %{
        academic_year_id: year_id,
        calendar_id: calendar.id,
        code: "year",
        label: "Synthetic year",
        start_on: start_on,
        end_on: Date.add(Date.utc_today(), 365),
        time_zone: Keyword.get(options, :time_zone, "Etc/UTC"),
        instructional_weekdays: [1, 2, 3, 4, 5],
        closures: [],
        periods: [
          %{
            id: UUID.generate(),
            period_type_key: "term",
            sequence: 1,
            label: "Synthetic term",
            start_on: start_on,
            end_on: Date.add(Date.utc_today(), 365)
          }
        ]
      })

    assert {:ok, draft} = Calendar.define_draft_academic_year(runtime, context_a(), definition)

    if status == "published" do
      assert {:ok, _} =
               Calendar.publish_academic_year(
                 runtime,
                 context_a(),
                 Map.merge(keys(), %{
                   calendar_id: calendar.id,
                   academic_year_id: year_id,
                   expected_version: draft.lock_version
                 })
               )
    end

    %{id: calendar.id, year_id: year_id, revision: draft.candidate_revision}
  end

  defp keys, do: %{idempotency_key: UUID.generate(), causation_id: UUID.generate()}
  defp person_input, do: Map.put(keys(), :display_name, "Synthetic Person")

  defp person!(f) do
    assert {:ok, person} = People.register_person(f.runtime, context_a(), person_input())
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
             apply(People, action, [f.runtime, context_a(), participation_input(f, person)])

    part
  end

  defp deny(f, capability) do
    assert {:ok, _} =
             query(
               f,
               "DELETE FROM platform_role_capability_grants g USING platform_capabilities c WHERE g.capability_id = c.id AND g.tenant_id = c.tenant_id AND c.tenant_id = $1 AND c.key = $2",
               [dump(@tenant_a), "classroom.core." <> capability]
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
        "SELECT (SELECT count(*) FROM platform_authority_audit_events WHERE action_name LIKE 'classroom.core.%'), (SELECT count(*) FROM platform_outbox_events WHERE aggregate_type LIKE 'classroom.core.%'), (SELECT count(*) FROM platform_authority_action_idempotency WHERE action_name LIKE 'classroom.core.%')"
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

               for key <- [
                     "classes.create",
                     "classes.read",
                     "enrolments.record",
                     "enrolments.end",
                     "enrolments.read",
                     "assignments.record",
                     "assignments.end",
                     "assignments.read",
                     "placements.record",
                     "placements.end",
                     "placements.read"
                   ] do
                 id = UUID.generate()
                 insert_capability(id, tenant_id, "classroom.core." <> key)
                 insert_grant(tenant_id, role_id, id)
               end

               for key <- [
                     "academics.calendar.definition.manage",
                     "academics.calendar.publication.publish",
                     "academics.calendar.read"
                   ] do
                 id = UUID.generate()
                 insert_capability(id, tenant_id, key)
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
          {"people.core", "1.0.0"},
          {"academics.calendar", "1.0.0"},
          {"classroom.core", "1.0.0"}
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
                 "DROP TRIGGER IF EXISTS test_fail_classroom_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_classroom_completion()")

               Repo.query!("""
               CREATE FUNCTION test_fail_classroom_completion()
               RETURNS trigger
               LANGUAGE plpgsql
               AS $$
               BEGIN
                 IF NEW.status = 'completed' AND
                    NEW.action_name LIKE 'classroom.core.%' THEN
                   RAISE EXCEPTION USING
                     ERRCODE = '40001',
                     MESSAGE = 'synthetic legal entity completion failure';
                 END IF;

                 RETURN NEW;
               END;
               $$;
               """)

               Repo.query!("""
               CREATE TRIGGER test_fail_classroom_completion
               BEFORE UPDATE OF status
               ON platform_authority_action_idempotency
               FOR EACH ROW
               EXECUTE FUNCTION test_fail_classroom_completion();
               """)

               :installed
             end)
  end

  defp remove_completion_failure(runtime) do
    assert {:ok, :removed} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_classroom_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_classroom_completion()")
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
