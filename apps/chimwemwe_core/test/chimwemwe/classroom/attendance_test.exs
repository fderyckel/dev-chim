defmodule Chimwemwe.Classroom.AttendanceTest do
  use ExUnit.Case, async: false
  import Chimwemwe.Classroom.Fixture
  alias Chimwemwe.Classroom.{Attendance, AttendanceFixture, Error, Foundation}
  alias Chimwemwe.Identity.PublicSessionAdapter
  alias Chimwemwe.People.Foundation, as: People
  alias Chimwemwe.Platform.PersistenceRuntime
  alias Chimwemwe.PublicApi.{ClassroomPlug, Router}
  alias Ecto.UUID

  setup do
    persistence = start_supervised!({PersistenceRuntime, runtime_options()})
    {:ok, f} = seed!(persistence)

    on_exit(fn ->
      for source <- [f.source, f.account_source],
          do: if(Process.alive?(source), do: Agent.stop(source))

      {:ok, cleanup} = PersistenceRuntime.start_link(runtime_options())

      try do
        clear_fixture(cleanup)
      after
        Supervisor.stop(cleanup)
      end
    end)

    f = AttendanceFixture.connect!(f)
    {class, enrolment, assignment, placement} = classroom!(f)
    old = Application.get_env(:chimwemwe_core, :public_session_cookie_keys)

    Application.put_env(:chimwemwe_core, :public_session_cookie_keys, [
      String.duplicate("synthetic-attendance-key-", 3)
    ])

    on_exit(fn ->
      if old,
        do: Application.put_env(:chimwemwe_core, :public_session_cookie_keys, old),
        else: Application.delete_env(:chimwemwe_core, :public_session_cookie_keys)
    end)

    {cookie, request} = AttendanceFixture.login!(f)

    Map.merge(f, %{
      class: class,
      enrolment: enrolment,
      assignment: assignment,
      placement: placement,
      request: request,
      cookie: cookie
    })
  end

  test "session-bound assigned class, explicit marks, atomic receipt and authoritative reload",
       f do
    assert {:ok, [%{id: id}]} = Attendance.assigned_classes(f.persistence, f.request)
    assert id == f.class.id
    assert {:ok, view} = Attendance.prepare(f.persistence, f.request, id)
    assert [%{mark: nil}] = view.students
    input = input(view)
    assert {:ok, receipt} = Attendance.submit(f.persistence, f.request, input)
    assert {:ok, ^receipt} = Attendance.submit(f.persistence, f.request, input)
    assert {:ok, saved} = Attendance.prepare(f.persistence, f.request, id)
    assert saved.submission_id == receipt["submission_id"]
    assert [%{mark: "present"}] = saved.students

    assert {:ok, %{rows: [[1, 1, 1]]}} =
             query(f, """
             SELECT (SELECT count(*) FROM classroom_attendance_submissions),
               (SELECT count(*) FROM platform_authority_audit_events WHERE action_name = 'classroom.attendance.submit'),
               (SELECT count(*) FROM platform_outbox_events WHERE aggregate_type = 'classroom.attendance.submission' AND classification = 'restricted')
             """)

    assert {:error, %Error{code: :conflict}} =
             Attendance.submit(f.persistence, f.request, Map.merge(input, keys()))

    assert {:error, %Error{code: :idempotency_conflict}} =
             Attendance.submit(f.persistence, f.request, %{
               input
               | marks: Enum.map(input.marks, &%{&1 | mark: "late"})
             })
  end

  test "missing, forged and revoked sessions cannot read or write", f do
    assert {:error, _} = Attendance.assigned_classes(f.persistence, nil)

    assert {:error, _} =
             Attendance.prepare(
               f.persistence,
               %{f.request | session_token: "invalid"},
               f.class.id
             )

    assert {:ok, view} = Attendance.prepare(f.persistence, f.request, f.class.id)
    assert {:ok, :logged_out} = PublicSessionAdapter.logout(f.persistence, f.request)
    assert {:error, _} = Attendance.submit(f.persistence, f.request, input(view))
    assert {:error, _} = Attendance.assigned_classes(f.persistence, f.request)
  end

  test "capability and staff binding are independent and checked again", f do
    assert {:ok, view} = Attendance.prepare(f.persistence, f.request, f.class.id)

    assert {:ok, _} =
             People.revoke_staff_account_association(
               f.runtime,
               context_a(),
               Map.merge(keys(), %{association_id: f.account.id, expected_version: 1})
             )

    assert {:error, %Error{code: :forbidden}} =
             Attendance.submit(f.persistence, f.request, input(view))

    assert {:ok, []} = Attendance.assigned_classes(f.persistence, f.request)
  end

  test "unknown, unassigned and cross-tenant classes do not disclose a roster", f do
    other = class!(f)

    for id <- [other.id, UUID.generate()] do
      assert {:error, %Error{code: :forbidden}} = Attendance.prepare(f.persistence, f.request, id)
    end

    assert {:error, _} =
             Attendance.prepare(f.persistence, %{f.request | context: context_b()}, f.class.id)

    assert {:error, _} =
             Attendance.prepare(f.persistence, %{f.request | support: %{}}, f.class.id)
  end

  test "changed person version invalidates prepared roster; saved roster stays pinned", f do
    assert {:ok, view} = Attendance.prepare(f.persistence, f.request, f.class.id)
    [student] = view.students

    assert {:ok, _} =
             People.revise_person_name(
               f.runtime,
               context_a(),
               Map.merge(keys(), %{
                 person_id: student.id,
                 expected_version: 1,
                 display_name: "Renamed synthetic student",
                 reason: :name_correction
               })
             )

    assert {:error, %Error{code: :stale}} =
             Attendance.submit(f.persistence, f.request, input(view))

    assert {:ok, current} = Attendance.prepare(f.persistence, f.request, f.class.id)
    assert {:ok, _} = Attendance.submit(f.persistence, f.request, input(current))

    assert {:ok, _} =
             Foundation.end_placement(
               f.persistence,
               context_a(),
               Map.merge(keys(), %{
                 placement_id: f.placement.id,
                 expected_version: 1,
                 effective_until: Date.add(Date.utc_today(), 1)
               })
             )

    assert {:ok, saved} = Attendance.prepare(f.persistence, f.request, f.class.id)
    assert [%{name: "Renamed synthetic student", mark: "present"}] = saved.students
  end

  test "incomplete, duplicate, extra and unrecognized marks are rejected", f do
    assert {:ok, view} = Attendance.prepare(f.persistence, f.request, f.class.id)
    good = input(view)

    for marks <- [
          [],
          good.marks ++ good.marks,
          [%{person_id: UUID.generate(), mark: "present"}],
          [%{hd(good.marks) | mark: "excused"}]
        ] do
      assert {:error, _} = Attendance.submit(f.persistence, f.request, %{good | marks: marks})
    end

    assert {:error, %Error{code: :stale}} =
             Attendance.submit(f.persistence, f.request, %{
               good
               | local_date: Date.to_iso8601(Date.add(Date.utc_today(), -1))
             })
  end

  test "two independent concurrent submissions create one immutable register", f do
    assert {:ok, view} = Attendance.prepare(f.persistence, f.request, f.class.id)

    outcomes =
      [input(view), input(view)]
      |> Task.async_stream(&Attendance.submit(f.persistence, f.request, &1))
      |> Enum.map(fn {:ok, result} -> result end)

    assert Enum.count(outcomes, &match?({:ok, _}, &1)) == 1
    assert Enum.count(outcomes, &match?({:error, %Error{code: :conflict}}, &1)) == 1
    assert {:error, _} = query(f, "DELETE FROM classroom_attendance_submissions")
  end

  test "revoked capability denies replay as well as new submission", f do
    assert {:ok, view} = Attendance.prepare(f.persistence, f.request, f.class.id)
    input = input(view)
    assert {:ok, _} = Attendance.submit(f.persistence, f.request, input)

    {:ok, _} =
      query(
        f,
        "DELETE FROM platform_role_capability_grants WHERE tenant_id = $1 AND capability_id IN (SELECT id FROM platform_capabilities WHERE tenant_id = $1 AND key = 'classroom.attendance.submit')",
        [dump(f.request.session.tenant_id)]
      )

    assert {:error, _} = Attendance.submit(f.persistence, f.request, input)
    assert {:ok, _} = Attendance.prepare(f.persistence, f.request, f.class.id)
  end

  test "exposure budgets accumulate distinct classes and people across reads", f do
    assert {:ok, _} = Attendance.prepare(f.persistence, f.request, f.class.id)
    ids = Enum.map(1..12, fn _ -> UUID.generate() |> dump() end)
    assert {:ok, _} = query(f, "UPDATE classroom_attendance_exposures SET class_ids = $1", [ids])

    assert {:error, %Error{code: :scope_limit}} =
             Attendance.prepare(f.persistence, f.request, f.class.id)

    people = Enum.map(1..720, fn _ -> UUID.generate() |> dump() end)

    assert {:ok, _} =
             query(
               f,
               "UPDATE classroom_attendance_exposures SET class_ids = '{}', person_ids = $1",
               [people]
             )

    assert {:error, %Error{code: :scope_limit}} =
             Attendance.prepare(f.persistence, f.request, f.class.id)

    assert {:ok, %{rows: [[720]]}} =
             query(f, "SELECT cardinality(person_ids) FROM classroom_attendance_exposures")
  end

  test "failure after audit and event insertion rolls back attendance and retry claim", f do
    assert {:ok, view} = Attendance.prepare(f.persistence, f.request, f.class.id)

    assert {:ok, _} =
             query(f, """
             CREATE FUNCTION test_fail_attendance() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
               IF NEW.action_name = 'classroom.attendance.submit' AND NEW.status = 'completed' THEN RAISE EXCEPTION 'synthetic failure'; END IF; RETURN NEW;
             END $$;
             """)

    assert {:ok, _} =
             query(
               f,
               "CREATE TRIGGER test_fail_attendance BEFORE UPDATE ON platform_authority_action_idempotency FOR EACH ROW EXECUTE FUNCTION test_fail_attendance()"
             )

    try do
      assert {:error, _} = Attendance.submit(f.persistence, f.request, input(view))

      assert {:ok, %{rows: [[0, 0, 0]]}} =
               query(
                 f,
                 "SELECT (SELECT count(*) FROM classroom_attendance_submissions), (SELECT count(*) FROM platform_outbox_events WHERE aggregate_type = 'classroom.attendance.submission'), (SELECT count(*) FROM platform_authority_action_idempotency WHERE action_name = 'classroom.attendance.submit')"
               )
    after
      query(f, "DROP TRIGGER test_fail_attendance ON platform_authority_action_idempotency")
      query(f, "DROP FUNCTION test_fail_attendance()")
    end

    assert {:ok, _} = Attendance.submit(f.persistence, f.request, input(view))
  end

  test "classroom HTTP stays closed by default and enforces session, origin, CSRF and exact inputs",
       f do
    keys = [:public_api, :local_classroom_enabled]
    previous = Map.new(keys, &{&1, Application.get_env(:chimwemwe_core, &1)})

    on_exit(fn ->
      Enum.each(previous, fn {key, value} ->
        if value == nil,
          do: Application.delete_env(:chimwemwe_core, key),
          else: Application.put_env(:chimwemwe_core, key, value)
      end)
    end)

    Application.put_env(:chimwemwe_core, :public_api,
      runtime: f.persistence,
      verifier: AttendanceFixture,
      origin: "https://localhost:3013"
    )

    Application.delete_env(:chimwemwe_core, :local_classroom_enabled)
    assert http(f, :get, "/api/v1/classroom/classes", %{}).status == 404
    Application.put_env(:chimwemwe_core, :local_classroom_enabled, true)

    remote = %{
      Plug.Test.conn(:get, "https://localhost:3013/api/v1/classroom/classes")
      | remote_ip: {203, 0, 113, 1}
    }

    assert ClassroomPlug.call(remote, []).status == 404
    foreign_host = Plug.Test.conn(:get, "https://other.example/api/v1/classroom/classes")
    assert ClassroomPlug.call(foreign_host, []).status == 404
    assert http(%{f | cookie: "invalid"}, :get, "/api/v1/classroom/classes", %{}).status == 401
    assert http(f, :get, "/api/v1/classroom/classes", %{}).status == 200
    path = "/api/v1/classroom/prepare-attendance"
    assert http(f, :post, path, %{class_id: f.class.id}, []).status == 403

    assert http(f, :post, path, %{class_id: f.class.id}, [
             {"origin", "https://other.example"},
             {"x-csrf-token", f.request.csrf_token}
           ]).status == 403

    assert http(f, :post, path, %{class_id: f.class.id, tenant_id: UUID.generate()}).status == 400
    conn = http(f, :post, path, %{class_id: f.class.id})
    assert conn.status == 200
    assert Plug.Conn.get_resp_header(conn, "cache-control") == ["no-store"]
    assert {:ok, view} = Attendance.prepare(f.persistence, f.request, f.class.id)
    assert http(f, :post, "/api/v1/classroom/submit-attendance", input(view)).status == 200
  end

  test "published calendar's non-instructional day prevents preparation and submission", f do
    calendar =
      calendar!(f, "published", weekdays: [rem(Date.day_of_week(Date.utc_today()), 7) + 1])

    {class, _, _, _} = classroom!(%{f | calendar: calendar})

    assert {:error, %Error{code: :non_instructional}} =
             Attendance.prepare(f.persistence, f.request, class.id)
  end

  test "new placement invalidates a prepared roster", f do
    assert {:ok, view} = Attendance.prepare(f.persistence, f.request, f.class.id)
    student = participation!(f, person!(f), :student)
    enrolment = enrolment!(%{f | student: student})

    assert {:ok, _} =
             Foundation.place_student(
               f.persistence,
               context_a(),
               placement_input(enrolment, f.class)
             )

    assert {:error, %Error{code: :stale}} =
             Attendance.submit(f.persistence, f.request, input(view))

    assert {:ok, %{students: [_, _]}} = Attendance.prepare(f.persistence, f.request, f.class.id)
  end

  test "more than twelve assigned classes refuses enumeration rather than truncating", f do
    for _ <- 1..12 do
      class = class!(f)

      assert {:ok, _} =
               Foundation.assign_teacher(f.persistence, context_a(), teacher_input(f, class))
    end

    assert {:error, %Error{code: :scope_limit}} =
             Attendance.assigned_classes(f.persistence, f.request)
  end

  test "roster over sixty refuses disclosure", f do
    for _ <- 1..60 do
      student = participation!(f, person!(f), :student)
      enrolment = enrolment!(%{f | student: student})

      assert {:ok, _} =
               Foundation.place_student(
                 f.persistence,
                 context_a(),
                 placement_input(enrolment, f.class)
               )
    end

    assert {:error, %Error{code: :scope_limit}} =
             Attendance.prepare(f.persistence, f.request, f.class.id)

    assert {:ok, %{rows: [[0]]}} = query(f, "SELECT count(*) FROM classroom_attendance_exposures")
  end

  defp http(f, method, path, input, headers \\ nil) do
    headers =
      headers || [{"origin", "https://localhost:3013"}, {"x-csrf-token", f.request.csrf_token}]

    conn =
      Plug.Test.conn(
        method,
        "https://localhost:3013" <> path,
        if(method == :post, do: Jason.encode!(input), else: nil)
      )

    conn =
      Enum.reduce(
        headers ++
          [
            {"content-type", "application/json"},
            {"accept", "application/json"},
            {"accept-language", "en-US,en;q=0.9"},
            {"cookie", PublicSessionAdapter.cookie_name() <> "=" <> f.cookie}
          ],
        conn,
        fn {key, value}, acc -> Plug.Conn.put_req_header(acc, key, value) end
      )

    conn = Plug.RequestId.call(conn, Plug.RequestId.init([]))

    conn =
      Plug.Parsers.call(
        conn,
        Plug.Parsers.init(parsers: [:json], pass: [], json_decoder: Jason, length: 32_768)
      )

    Router.call(conn, Router.init([]))
  end

  defp input(view),
    do:
      Map.merge(keys(), %{
        class_id: view.class_id,
        local_date: view.local_date,
        calendar_revision: view.calendar_revision,
        roster_basis: view.roster_basis,
        marks: Enum.map(view.students, &%{person_id: &1.id, mark: "present"})
      })
end
