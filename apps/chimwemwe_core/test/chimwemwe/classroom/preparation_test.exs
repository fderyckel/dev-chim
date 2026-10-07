defmodule Chimwemwe.Classroom.PreparationTest do
  use ExUnit.Case, async: false

  import Chimwemwe.Classroom.Fixture

  alias Chimwemwe.Classroom.{Attendance, AttendanceFixture, Error, Preparation}
  alias Chimwemwe.Platform.{PersistenceRuntime, TrustedActor}
  alias Ecto.UUID

  setup do
    persistence = start_supervised!({PersistenceRuntime, runtime_options()})
    {:ok, fixture} = seed!(persistence)
    fixture = AttendanceFixture.connect!(fixture)
    workspace_id = UUID.generate()
    insert_workspace!(fixture, workspace_id)

    previous_keys = Application.get_env(:chimwemwe_core, :public_session_cookie_keys)

    Application.put_env(:chimwemwe_core, :public_session_cookie_keys, [
      String.duplicate("synthetic-preparation-key-", 3)
    ])

    on_exit(fn ->
      if previous_keys,
        do: Application.put_env(:chimwemwe_core, :public_session_cookie_keys, previous_keys),
        else: Application.delete_env(:chimwemwe_core, :public_session_cookie_keys)

      for source <- [fixture.source, fixture.account_source],
          do: if(Process.alive?(source), do: Agent.stop(source))

      {:ok, cleanup} = PersistenceRuntime.start_link(runtime_options())

      try do
        clear_fixture(cleanup)
      after
        Supervisor.stop(cleanup)
      end
    end)

    {cookie, request} = AttendanceFixture.login!(fixture)

    Map.merge(fixture, %{
      cookie: cookie,
      request: request,
      workspace_id: workspace_id
    })
  end

  test "administrator prepares one class and student for the educator attendance workflow", f do
    assert {:ok, %{rows: [[audit_before, outbox_before]]}} = preparation_evidence(f)

    assert {:ok,
            %{
              institution_name: "Synthetic Learning Institution",
              academic_year_label: "Synthetic year",
              class: nil,
              students: []
            }} = Preparation.view(f.persistence, f.request, f.workspace_id)

    class_input = class_input()

    assert {:ok, prepared} =
             Preparation.prepare_class(f.persistence, f.request, f.workspace_id, class_input)

    assert prepared.class.label == "Year 6 Blue"
    assert prepared.educator_name == "Synthetic Person"

    assert {:ok, ^prepared} =
             Preparation.prepare_class(f.persistence, f.request, f.workspace_id, class_input)

    student_input = student_input("Synthetic Learner A")

    assert {:ok, %{students: [%{name: "Synthetic Learner A"}]} = with_student} =
             Preparation.add_student(
               f.persistence,
               f.runtime,
               f.request,
               f.workspace_id,
               student_input
             )

    assert {:ok, ^with_student} =
             Preparation.add_student(
               f.persistence,
               f.runtime,
               f.request,
               f.workspace_id,
               student_input
             )

    assert {:ok, [%{id: class_id, label: "Year 6 Blue"}]} =
             Attendance.assigned_classes(f.persistence, f.request)

    assert class_id == prepared.class.id

    assert {:ok, %{students: [%{name: "Synthetic Learner A"}]}} =
             Attendance.prepare(f.persistence, f.request, class_id)

    assert {:ok, %{rows: [[audit_after, outbox_after]]}} = preparation_evidence(f)
    assert audit_after - audit_before == 6
    assert outbox_after - outbox_before == 6
  end

  test "session, workspace and every underlying capability fail closed", f do
    assert {:error, %Error{code: :forbidden}} =
             Preparation.view(
               f.persistence,
               %{f.request | session_token: "forged"},
               f.workspace_id
             )

    assert {:error, %Error{code: :forbidden}} =
             Preparation.view(f.persistence, f.request, UUID.generate())

    deny_capability(f, "classroom.core.assignments.record")

    assert {:error, %{code: :forbidden}} =
             Preparation.prepare_class(
               f.persistence,
               f.request,
               f.workspace_id,
               class_input()
             )

    assert {:ok, %{rows: [[0, nil]]}} =
             query(
               f,
               """
               SELECT
                 (SELECT count(*) FROM classroom_classes),
                 (SELECT class_id FROM classroom_preparation_workspaces WHERE id = $1)
               """,
               [dump(f.workspace_id)]
             )

    assert {:ok, %{rows: [[0, 0, 0]]}} =
             query(f, """
             SELECT
               (SELECT count(*) FROM platform_authority_audit_events WHERE action_name LIKE 'classroom.core.%'),
               (SELECT count(*) FROM platform_outbox_events WHERE aggregate_type LIKE 'classroom.core.%'),
               (SELECT count(*) FROM platform_authority_action_idempotency WHERE action_name LIKE 'classroom.core.%')
             """)
  end

  test "a failed placement rolls back person, participation and enrolment", f do
    assert {:ok, _} =
             Preparation.prepare_class(f.persistence, f.request, f.workspace_id, class_input())

    deny_capability(f, "classroom.core.placements.record")

    assert {:error, %{code: :forbidden}} =
             Preparation.add_student(
               f.persistence,
               f.runtime,
               f.request,
               f.workspace_id,
               student_input("Must Roll Back")
             )

    assert {:ok, %{rows: [[0, 0, 0]]}} =
             query(f, """
             SELECT
               (SELECT count(*) FROM people_persons WHERE display_name = 'Must Roll Back'),
               (SELECT count(*) FROM classroom_enrolments),
               (SELECT count(*) FROM classroom_placements)
             """)
  end

  test "read capabilities gate action responses before any preparation write", f do
    deny_capability(f, "people.core.persons.read")

    assert {:error, %{code: :forbidden}} =
             Preparation.prepare_class(
               f.persistence,
               f.request,
               f.workspace_id,
               class_input()
             )

    assert {:ok, %{rows: [[0, nil]]}} =
             query(
               f,
               """
               SELECT
                 (SELECT count(*) FROM classroom_classes),
                 (SELECT class_id FROM classroom_preparation_workspaces WHERE id = $1)
               """,
               [dump(f.workspace_id)]
             )
  end

  test "one exact workspace refuses a sixty-first student without partial records", f do
    assert {:ok, _} =
             Preparation.prepare_class(f.persistence, f.request, f.workspace_id, class_input())

    for number <- 1..60 do
      assert {:ok, _} =
               Preparation.add_student(
                 f.persistence,
                 f.runtime,
                 f.request,
                 f.workspace_id,
                 student_input("Synthetic Learner #{number}")
               )
    end

    assert {:error, %Error{code: :scope_limit}} =
             Preparation.add_student(
               f.persistence,
               f.runtime,
               f.request,
               f.workspace_id,
               student_input("Overflow Learner")
             )

    assert {:ok, %{students: students}} =
             Preparation.view(f.persistence, f.request, f.workspace_id)

    assert length(students) == 60

    assert {:ok, %{rows: [[0, 60]]}} =
             query(f, """
             SELECT
               (SELECT count(*) FROM people_persons WHERE display_name = 'Overflow Learner'),
               (SELECT count(*) FROM classroom_placements)
             """)
  end

  defp insert_workspace!(f, workspace_id) do
    actor = TrustedActor.actor_id(context_a().actor)
    tenant = TrustedActor.tenant_id(context_a().actor)

    assert {:ok, %{num_rows: 1}} =
             query(
               f,
               """
               INSERT INTO classroom_preparation_workspaces
                 (id, tenant_id, actor_id, membership_id, institutional_unit_id, calendar_id,
                  academic_year_id, calendar_revision, educator_participation_id, lock_version, inserted_at)
               VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 1, NOW())
               """,
               [
                 dump(workspace_id),
                 dump(tenant),
                 dump(actor),
                 dump(f.membership_a),
                 dump(f.unit.id),
                 dump(f.calendar.id),
                 dump(f.calendar.year_id),
                 f.calendar.revision,
                 dump(f.staff.id)
               ]
             )
  end

  defp deny_capability(f, capability) do
    assert {:ok, _} =
             query(
               f,
               """
               DELETE FROM platform_role_capability_grants grant_row
               USING platform_capabilities capability_row
               WHERE grant_row.tenant_id = capability_row.tenant_id
                 AND grant_row.capability_id = capability_row.id
                 AND grant_row.tenant_id = $1 AND capability_row.key = $2
               """,
               [dump(TrustedActor.tenant_id(context_a().actor)), capability]
             )
  end

  defp class_input do
    Map.merge(keys(), %{code: "year_6_blue", label: "Year 6 Blue"})
  end

  defp student_input(name), do: Map.put(keys(), :display_name, name)

  defp preparation_evidence(f) do
    query(f, """
    SELECT
      (SELECT count(*) FROM platform_authority_audit_events
       WHERE action_name LIKE 'people.core.%' OR action_name LIKE 'classroom.core.%'),
      (SELECT count(*) FROM platform_outbox_events
       WHERE aggregate_type LIKE 'people.core.%' OR aggregate_type LIKE 'classroom.core.%')
    """)
  end
end
