# Deliberately test-only: this process owns an isolated, newly-created synthetic database.
alias Chimwemwe.Classroom.{AttendanceFixture, Fixture}
alias Chimwemwe.Platform.TrustedActor
alias Chimwemwe.Platform.PersistenceRuntime
alias Ecto.UUID

unless Mix.env() == :test and System.get_env("CHIMWEMWE_CLASSROOM_DEMO") == "true" and
         String.starts_with?(
           System.get_env("CHIMWEMWE_TEST_DATABASE", ""),
           "chimwemwe_attendance_demo_"
         ) do
  raise "Use bin/classroom-demo with its isolated synthetic database"
end

{:ok, runtime} = PersistenceRuntime.start_link(Fixture.runtime_options())

{:ok, %{rows: [[0]]}} =
  Fixture.query(%{persistence: runtime}, "SELECT count(*) FROM people_persons")

{:ok, fixture} = Fixture.seed!(runtime)
fixture = AttendanceFixture.connect!(fixture)

workspace_id = UUID.generate()
actor_id = TrustedActor.actor_id(Fixture.context_a().actor)

{:ok, _} =
  Fixture.query(
    fixture,
    """
    INSERT INTO classroom_preparation_workspaces
      (id, tenant_id, actor_id, membership_id, institutional_unit_id, calendar_id,
       academic_year_id, calendar_revision, educator_participation_id, lock_version, inserted_at)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 1, NOW())
    """,
    [
      Fixture.dump(workspace_id),
      Fixture.dump(TrustedActor.tenant_id(Fixture.context_a().actor)),
      Fixture.dump(actor_id),
      Fixture.dump(fixture.membership_a),
      Fixture.dump(fixture.unit.id),
      Fixture.dump(fixture.calendar.id),
      Fixture.dump(fixture.calendar.year_id),
      fixture.calendar.revision,
      Fixture.dump(fixture.staff.id)
    ]
  )

calendar = Fixture.calendar!(fixture, "draft")
{class, _enrolment, _assignment, _placement} = Fixture.classroom!(fixture)

for name <- ["Synthetic Student B", "Synthetic Student C"] do
  {:ok, person} =
    Chimwemwe.People.Foundation.register_person(
      fixture.runtime,
      Fixture.context_a(),
      Map.put(Fixture.keys(), :display_name, name)
    )

  student = Fixture.participation!(fixture, person, :student)
  enrolment = Fixture.enrolment!(%{fixture | student: student})

  {:ok, _} =
    Chimwemwe.Classroom.Foundation.place_student(
      runtime,
      Fixture.context_a(),
      Fixture.placement_input(enrolment, class)
    )
end

{:ok, _} =
  Fixture.query(
    fixture,
    "DELETE FROM platform_role_capability_grants WHERE tenant_id = $1 AND capability_id NOT IN (SELECT id FROM platform_capabilities WHERE tenant_id = $1 AND key IN ('academics.calendar.definition.manage','academics.calendar.publication.publish','academics.calendar.read','people.core.persons.register','people.core.persons.read','people.core.participations.record_student','classroom.core.classes.create','classroom.core.classes.read','classroom.core.enrolments.record','classroom.core.assignments.record','classroom.core.placements.record','classroom.attendance.read','classroom.attendance.submit','classroom.attendance.correct'))",
    [Fixture.dump(Chimwemwe.Platform.TrustedActor.tenant_id(Fixture.context_a().actor))]
  )

Application.put_env(:chimwemwe_core, :public_session_cookie_keys, [
  Base.encode64(:crypto.strong_rand_bytes(48))
])

Application.put_env(:chimwemwe_core, :local_classroom_enabled, true)
Application.put_env(:chimwemwe_core, :local_calendar_enabled, true)

Application.put_env(:chimwemwe_core, :local_calendar_target, %{
  academic_year_id: calendar.year_id,
  calendar_id: calendar.id,
  institutional_unit_id: fixture.unit.id
})

Application.put_env(:chimwemwe_core, :public_api,
  runtime: runtime,
  verifier: AttendanceFixture,
  origin: "https://localhost:3013",
  preparation: [people_runtime: fixture.runtime, workspace_id: workspace_id]
)

defmodule Chimwemwe.Classroom.DemoPlug do
  import Plug.Conn
  def init(fixture), do: fixture

  def call(conn, fixture) do
    conn = Plug.RequestId.call(conn, Plug.RequestId.init([]))

    conn =
      Plug.Parsers.call(
        conn,
        Plug.Parsers.init(parsers: [:json], pass: [], json_decoder: Jason, length: 32_768)
      )

    if conn.request_path == "/api/v1/classroom-demo/sign-in" do
      login(conn, fixture)
    else
      Chimwemwe.PublicApi.Router.call(conn, Chimwemwe.PublicApi.Router.init([]))
    end
  end

  defp login(conn, fixture) do
    if conn.method == "POST" and get_req_header(conn, "origin") == ["https://localhost:3013"] and
         get_req_header(conn, "content-type") == ["application/json"] and conn.body_params == %{} do
      {cookie, _request} = Chimwemwe.Classroom.AttendanceFixture.login!(fixture)

      conn
      |> put_resp_cookie(
        Chimwemwe.Identity.PublicSessionAdapter.cookie_name(),
        cookie,
        Chimwemwe.Identity.PublicSessionAdapter.cookie_options()
      )
      |> put_resp_header("cache-control", "no-store")
      |> send_resp(204, "")
    else
      conn |> put_resp_header("cache-control", "no-store") |> send_resp(403, "")
    end
  end
end

{:ok, _server} =
  Bandit.start_link(
    plug: {Chimwemwe.Classroom.DemoPlug, fixture},
    ip: {127, 0, 0, 1},
    port: 4013,
    startup_log: false
  )

IO.puts("Synthetic classroom and calendar writers ready on loopback.")
Process.sleep(:infinity)
