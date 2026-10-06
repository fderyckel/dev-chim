defmodule Chimwemwe.Classroom.FoundationTest do
  use ExUnit.Case, async: false
  import Chimwemwe.Classroom.Fixture
  alias Chimwemwe.Classroom.{Error, Foundation}
  alias Chimwemwe.InstitutionalStructure.Foundation, as: Institutions
  alias Chimwemwe.People.Foundation, as: People
  alias Chimwemwe.People.{Runtime, TestVerifier}

  alias Chimwemwe.Platform.{
    Outbox,
    Persistence,
    PersistenceRuntime,
    ResourceContract
  }

  alias Chimwemwe.Platform.Outbox.ConsumerRegistry
  alias Chimwemwe.Repo
  alias Ecto.UUID
  @tenant_a "41414141-4141-4141-8141-414141414141"
  @tenant_b "42424242-4242-4242-8242-424242424242"
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
end
