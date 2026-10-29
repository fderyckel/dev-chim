defmodule Chimwemwe.AcademicCalendar.ConnectedPreparationTest do
  use ExUnit.Case, async: false

  import Chimwemwe.Classroom.Fixture

  alias Chimwemwe.AcademicCalendar.{ConnectedPreparation, Error}
  alias Chimwemwe.Classroom.AttendanceFixture
  alias Chimwemwe.Identity.PublicSessionAdapter
  alias Chimwemwe.Platform.PersistenceRuntime
  alias Chimwemwe.PublicApi.{CalendarPlug, Router}
  alias Ecto.UUID

  setup do
    persistence = start_supervised!({PersistenceRuntime, runtime_options()})
    {:ok, fixture} = seed!(persistence)
    fixture = AttendanceFixture.connect!(fixture)
    calendar = calendar!(fixture, "draft")

    previous =
      Map.new(
        [
          :local_calendar_enabled,
          :local_calendar_target,
          :public_api,
          :public_session_cookie_keys
        ],
        &{&1, Application.get_env(:chimwemwe_core, &1)}
      )

    Application.put_env(:chimwemwe_core, :public_session_cookie_keys, [
      String.duplicate("synthetic-calendar-key-", 3)
    ])

    Application.put_env(:chimwemwe_core, :public_api,
      runtime: persistence,
      verifier: AttendanceFixture,
      origin: "https://localhost:3013"
    )

    target = %{
      academic_year_id: calendar.year_id,
      calendar_id: calendar.id,
      institutional_unit_id: fixture.unit.id
    }

    Application.put_env(:chimwemwe_core, :local_calendar_target, target)
    {cookie, request} = AttendanceFixture.login!(fixture)

    on_exit(fn ->
      for source <- [fixture.source, fixture.account_source],
          do: if(Process.alive?(source), do: Agent.stop(source))

      Enum.each(previous, fn {key, value} ->
        if value == nil,
          do: Application.delete_env(:chimwemwe_core, key),
          else: Application.put_env(:chimwemwe_core, key, value)
      end)

      {:ok, cleanup} = PersistenceRuntime.start_link(runtime_options())

      try do
        clear_fixture(cleanup)
      after
        Supervisor.stop(cleanup)
      end
    end)

    Map.merge(fixture, %{calendar: calendar, cookie: cookie, request: request, target: target})
  end

  test "session-bound draft save, authoritative reload, publication and date resolution",
       fixture do
    assert {:ok, draft} =
             ConnectedPreparation.read(fixture.persistence, fixture.request, fixture.target)

    assert draft.status == "draft"
    input = draft_input(draft, %{label: "Reviewed synthetic year"})

    assert {:ok, saved} =
             ConnectedPreparation.save(
               fixture.persistence,
               fixture.request,
               fixture.target,
               input
             )

    assert saved.lock_version == draft.lock_version + 1
    assert saved.definition.label == "Reviewed synthetic year"

    assert {:ok, reloaded} =
             ConnectedPreparation.read(fixture.persistence, fixture.request, fixture.target)

    assert reloaded == saved

    assert {:error, %Error{code: :stale}} =
             ConnectedPreparation.save(
               fixture.persistence,
               fixture.request,
               fixture.target,
               %{input | idempotency_key: UUID.generate(), causation_id: UUID.generate()}
             )

    assert {:ok, published} =
             ConnectedPreparation.publish(
               fixture.persistence,
               fixture.request,
               fixture.target,
               Map.merge(keys(), %{expected_version: saved.lock_version})
             )

    assert published.status == "published"
    assert published.lock_version == saved.lock_version + 1

    assert {:ok, resolution} =
             ConnectedPreparation.resolve(
               fixture.persistence,
               fixture.request,
               fixture.target,
               published.definition.start_on
             )

    assert resolution.status == "instructional"
    assert resolution.reason == "instructional_weekday"
    assert resolution.candidate_revision == published.candidate_revision

    assert {:error, %Error{code: :conflict}} =
             ConnectedPreparation.publish(
               fixture.persistence,
               fixture.request,
               fixture.target,
               Map.merge(keys(), %{expected_version: published.lock_version})
             )
  end

  test "revoked session, support mode, capability and server target fail closed", fixture do
    assert {:error, %Error{code: :forbidden}} =
             ConnectedPreparation.read(
               fixture.persistence,
               %{fixture.request | support: %{}},
               fixture.target
             )

    assert {:ok, draft} =
             ConnectedPreparation.read(fixture.persistence, fixture.request, fixture.target)

    {:ok, _} =
      query(
        fixture,
        "DELETE FROM platform_role_capability_grants WHERE tenant_id = $1 AND capability_id IN (SELECT id FROM platform_capabilities WHERE tenant_id = $1 AND key = 'academics.calendar.definition.manage')",
        [dump(fixture.request.session.tenant_id)]
      )

    assert {:error, %Error{code: :forbidden}} =
             ConnectedPreparation.save(
               fixture.persistence,
               fixture.request,
               fixture.target,
               draft_input(draft)
             )

    assert {:error, %Error{code: :forbidden}} =
             ConnectedPreparation.read(
               fixture.persistence,
               fixture.request,
               %{fixture.target | institutional_unit_id: UUID.generate()}
             )

    assert {:ok, :logged_out} =
             PublicSessionAdapter.logout(fixture.persistence, fixture.request)

    assert {:error, %Error{code: :forbidden}} =
             ConnectedPreparation.read(fixture.persistence, fixture.request, fixture.target)
  end

  test "inactive calendar module denies the connected read", fixture do
    {:ok, _} =
      query(
        fixture,
        "UPDATE platform_module_activations SET state = 'inactive', replay_from_cursor = 0, projection_ready = false, reconciliation_required = true, deactivated_at = NOW(), lock_version = lock_version + 1 WHERE tenant_id = $1 AND entitlement_id IN (SELECT id FROM platform_module_entitlements WHERE tenant_id = $1 AND module_key = 'academics.calendar')",
        [dump(fixture.request.session.tenant_id)]
      )

    assert {:error, %Error{code: :module_unavailable}} =
             ConnectedPreparation.read(fixture.persistence, fixture.request, fixture.target)
  end

  test "calendar HTTP is disabled by default and enforces target, session, origin, CSRF and exact input",
       fixture do
    Application.delete_env(:chimwemwe_core, :local_calendar_enabled)
    assert http(fixture, :get, "/api/v1/calendar/preparation", %{}).status == 404
    Application.put_env(:chimwemwe_core, :local_calendar_enabled, true)

    remote = %{
      Plug.Test.conn(:get, "https://localhost:3013/api/v1/calendar/preparation")
      | remote_ip: {203, 0, 113, 1}
    }

    assert CalendarPlug.call(remote, []).status == 404

    assert http(%{fixture | cookie: "invalid"}, :get, "/api/v1/calendar/preparation", %{}).status ==
             401

    draft_response = http(fixture, :get, "/api/v1/calendar/preparation", %{})
    assert draft_response.status == 200
    assert Plug.Conn.get_resp_header(draft_response, "cache-control") == ["no-store"]
    draft = Jason.decode!(draft_response.resp_body)["data"]
    path = "/api/v1/calendar/save-draft"
    input = http_draft_input(draft)
    assert http(fixture, :post, path, input, []).status == 403

    assert http(fixture, :post, path, input, [
             {"origin", "https://other.example"},
             {"x-csrf-token", fixture.request.csrf_token}
           ]).status == 403

    assert http(fixture, :post, path, Map.put(input, "tenant_id", UUID.generate())).status == 400
    assert http(fixture, :post, path, input).status == 200

    assert http(fixture, :post, path, Map.put(input, "idempotency_key", UUID.generate())).status ==
             409
  end

  defp draft_input(view, changes \\ %{}) do
    view.definition
    |> Map.merge(keys())
    |> Map.put(:expected_version, view.lock_version)
    |> Map.merge(changes)
  end

  defp http_draft_input(view) do
    view["definition"]
    |> Map.merge(%{
      "causation_id" => UUID.generate(),
      "expected_version" => view["lock_version"],
      "idempotency_key" => UUID.generate()
    })
  end

  defp http(fixture, method, path, input, headers \\ nil) do
    headers =
      headers ||
        [
          {"origin", "https://localhost:3013"},
          {"x-csrf-token", fixture.request.csrf_token}
        ]

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
            {"cookie", PublicSessionAdapter.cookie_name() <> "=" <> fixture.cookie}
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
end
