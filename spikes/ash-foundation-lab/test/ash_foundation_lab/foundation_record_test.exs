defmodule AshFoundationLab.FoundationRecordTest do
  use ExUnit.Case, async: true

  alias AshFoundationLab.Actor
  alias AshFoundationLab.FoundationRecord
  alias AshFoundationLab.JsonApiRouter
  alias AshFoundationLab.Repo
  alias AshFoundationLab.Telemetry
  alias Ecto.Adapters.SQL
  alias Ecto.Adapters.SQL.Sandbox
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  import Plug.Conn, only: [put_req_header: 3]
  import Plug.Test, only: [conn: 3]

  setup do
    owner = Sandbox.start_owner!(Repo, shared: false)
    on_exit(fn -> Sandbox.stop_owner(owner) end)

    {:ok, access_fixture()}
  end

  test "an authorized actor reads and performs the named transition", fixture do
    record = create_record(fixture.tenant_a, fixture.authorized_actor)
    correlation_id = UUID.generate()
    causation_id = UUID.generate()

    assert [visible_record] =
             FoundationRecord
             |> Ash.Query.set_tenant(fixture.tenant_a)
             |> Ash.read!(actor: fixture.authorized_actor)

    assert visible_record.id == record.id

    assert {:ok, submitted} =
             record
             |> submission_changeset(fixture.tenant_a, correlation_id, causation_id)
             |> Ash.update(actor: fixture.authorized_actor)

    assert submitted.status == :in_review
    assert submitted.lock_version == 2
    assert is_binary(submitted.audit_reference)

    assert [event] = outbox_events(fixture.tenant_a, record.id)
    assert event.actor_id == fixture.authorized_actor.id
    assert event.aggregate_type == "foundation_record"
    assert event.event_type == "foundation_record.submitted_for_review"
    assert event.schema_version == 1
    assert event.correlation_id == correlation_id
    assert event.causation_id == causation_id
    assert event.audit_reference == submitted.audit_reference
    assert event.classification == "internal"
    assert event.payload == %{"to_status" => "in_review"}
    refute Map.has_key?(event.payload, "name")
  end

  test "the generated interface exposes only the named transition route" do
    assert [
             %{
               verb: :patch,
               path: "/foundation-records/:id/submit-for-review"
             }
           ] = AshJsonApi.Router.formatted_routes(JsonApiRouter)
  end

  test "an authorized JSON:API request performs the named transition", fixture do
    record = create_record(fixture.tenant_a, fixture.authorized_actor)
    correlation_id = UUID.generate()
    causation_id = UUID.generate()

    response =
      json_api_request(
        record,
        actor: fixture.authorized_actor,
        tenant: fixture.tenant_a,
        correlation_id: correlation_id,
        causation_id: causation_id
      )

    assert response.status == 200

    assert %{
             "data" => %{
               "id" => id,
               "type" => "foundation-record",
               "attributes" =>
                 %{
                   "status" => "in_review",
                   "lock_version" => 2,
                   "audit_reference" => audit_reference
                 } = attributes
             }
           } = Jason.decode!(response.resp_body)

    assert id == record.id
    assert is_binary(audit_reference)
    refute Map.has_key?(attributes, "tenant_id")

    assert [event] = outbox_events(fixture.tenant_a, record.id)
    assert event.actor_id == fixture.authorized_actor.id
    assert event.correlation_id == correlation_id
    assert event.causation_id == causation_id
    assert event.audit_reference == audit_reference
  end

  test "the generated interface denies an actor without the transition capability", fixture do
    record = create_record(fixture.tenant_a, fixture.authorized_actor)

    response =
      json_api_request(
        record,
        actor: fixture.read_only_actor,
        tenant: fixture.tenant_a
      )

    assert response.status == 403
    assert_record_remains_draft(record, fixture)
  end

  test "cross-tenant JSON:API requests do not disclose record existence", fixture do
    record = create_record(fixture.tenant_a, fixture.authorized_actor)

    existing_response =
      json_api_request(
        record,
        actor: fixture.other_tenant_actor,
        tenant: fixture.tenant_b
      )

    unknown_record = %{record | id: UUID.generate()}

    unknown_response =
      unknown_record
      |> json_api_request(
        actor: fixture.other_tenant_actor,
        tenant: fixture.tenant_b
      )

    assert existing_response.status == 404
    assert unknown_response.status == existing_response.status

    assert json_api_error_fingerprint(existing_response, record.id) ==
             json_api_error_fingerprint(unknown_response, unknown_record.id)

    assert_record_remains_draft(record, fixture)
  end

  test "the generated interface fails closed when actor or tenant context is missing", fixture do
    record = create_record(fixture.tenant_a, fixture.authorized_actor)

    actorless_response = json_api_request(record, tenant: fixture.tenant_a)
    tenantless_response = json_api_request(record, actor: fixture.authorized_actor)

    assert actorless_response.status in 400..499
    assert tenantless_response.status in 400..499
    assert_record_remains_draft(record, fixture)
  end

  test "a generic JSON:API update cannot bypass the named action", fixture do
    record = create_record(fixture.tenant_a, fixture.authorized_actor)

    response =
      json_api_request(
        record,
        actor: fixture.authorized_actor,
        tenant: fixture.tenant_a,
        route: "/foundation-records/#{record.id}",
        attributes: %{"status" => "in_review"}
      )

    assert response.status == 404
    assert_record_remains_draft(record, fixture)
  end

  test "JSON:API telemetry is correlated, tenant-safe, and payload-free", fixture do
    handler_id = {__MODULE__, self(), make_ref()}

    :ok =
      :telemetry.attach(
        handler_id,
        Telemetry.event_name(),
        fn event_name, measurements, metadata, test_process ->
          send(test_process, {:captured_telemetry, event_name, measurements, metadata})
        end,
        self()
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    sensitive_marker = "synthetic-restricted-marker"

    record =
      create_record(
        fixture.tenant_a,
        fixture.authorized_actor,
        sensitive_marker
      )

    correlation_id = UUID.generate()

    assert %{status: 200} =
             json_api_request(
               record,
               actor: fixture.authorized_actor,
               tenant: fixture.tenant_a,
               correlation_id: correlation_id
             )

    assert_receive {
      :captured_telemetry,
      [:ash_foundation_lab, :json_api, :dispatch],
      %{count: 1},
      metadata
    }

    assert metadata == %{
             action: :submit_for_review,
             classification: :internal,
             correlation_id: correlation_id,
             event_version: 1,
             tenant_reference: metadata.tenant_reference,
             transport: :json_api
           }

    assert String.match?(metadata.tenant_reference, ~r/^tenant-[0-9a-f]{24}$/)

    serialized_metadata = inspect(metadata)
    refute serialized_metadata =~ fixture.tenant_a
    refute serialized_metadata =~ fixture.authorized_actor.id
    refute serialized_metadata =~ record.id
    refute serialized_metadata =~ sensitive_marker

    denied_record = create_record(fixture.tenant_a, fixture.authorized_actor, sensitive_marker)
    denied_correlation_id = UUID.generate()

    assert %{status: 403} =
             json_api_request(
               denied_record,
               actor: fixture.read_only_actor,
               tenant: fixture.tenant_a,
               correlation_id: denied_correlation_id
             )

    assert_receive {
      :captured_telemetry,
      [:ash_foundation_lab, :json_api, :dispatch],
      %{count: 1},
      denied_metadata
    }

    assert denied_metadata.correlation_id == denied_correlation_id
    assert denied_metadata.tenant_reference == metadata.tenant_reference

    serialized_denied_metadata = inspect(denied_metadata)
    refute serialized_denied_metadata =~ fixture.read_only_actor.id
    refute serialized_denied_metadata =~ denied_record.id
    refute serialized_denied_metadata =~ sensitive_marker
  end

  test "an actor without the transition capability is denied", fixture do
    record = create_record(fixture.tenant_a, fixture.authorized_actor)

    assert {:error, %Ash.Error.Forbidden{}} =
             record
             |> submission_changeset(fixture.tenant_a)
             |> Ash.update(actor: fixture.read_only_actor)
  end

  test "another tenant cannot read, infer, or mutate the record", fixture do
    record = create_record(fixture.tenant_a, fixture.authorized_actor)

    assert [] ==
             FoundationRecord
             |> Ash.Query.set_tenant(fixture.tenant_b)
             |> Ash.read!(actor: fixture.other_tenant_actor)

    assert_raise Ash.Error.Forbidden, fn ->
      FoundationRecord
      |> Ash.Query.set_tenant(fixture.tenant_a)
      |> Ash.read!(actor: fixture.other_tenant_actor)
    end

    assert {:error, %Ash.Error.Forbidden{}} =
             record
             |> submission_changeset(fixture.tenant_a)
             |> Ash.update(actor: fixture.other_tenant_actor)
  end

  test "renamed and composed tenant roles grant the same capability", fixture do
    rename_role(fixture.tenant_a, fixture.composed_role, "Renamed review circle")

    record = create_record(fixture.tenant_a, fixture.composed_actor)

    assert {:ok, submitted} =
             record
             |> submission_changeset(fixture.tenant_a)
             |> Ash.update(actor: fixture.composed_actor)

    assert submitted.status == :in_review
  end

  test "missing actor or tenant context fails closed", fixture do
    assert_raise Ash.Error.Invalid, fn ->
      Ash.read!(FoundationRecord, actor: fixture.authorized_actor)
    end

    assert_raise Ash.Error.Forbidden, fn ->
      FoundationRecord
      |> Ash.Query.set_tenant(fixture.tenant_a)
      |> Ash.read!()
    end

    assert_raise Ash.Error.Forbidden, fn ->
      FoundationRecord
      |> Ash.Changeset.for_create(:create, %{name: "Actorless record"})
      |> Ash.Changeset.set_tenant(fixture.tenant_a)
      |> Ash.create!()
    end

    assert_raise Ash.Error.Invalid, fn ->
      FoundationRecord
      |> Ash.Changeset.for_create(:create, %{name: "Unscoped record"})
      |> Ash.create!(actor: fixture.authorized_actor)
    end
  end

  test "an invalid state transition returns the registered validation error", fixture do
    record = create_record(fixture.tenant_a, fixture.authorized_actor)
    submitted = submit!(record, fixture.tenant_a, fixture.authorized_actor)

    assert {:error, %Ash.Error.Invalid{} = error} =
             submitted
             |> submission_changeset(fixture.tenant_a)
             |> Ash.update(actor: fixture.authorized_actor)

    assert Exception.message(error) =~ "record must be in draft state"
  end

  test "a stale transition returns an optimistic-lock conflict", fixture do
    stale_record = create_record(fixture.tenant_a, fixture.authorized_actor)
    _submitted = submit!(stale_record, fixture.tenant_a, fixture.authorized_actor)

    assert {:error, %Ash.Error.Invalid{} = error} =
             stale_record
             |> submission_changeset(fixture.tenant_a)
             |> Ash.update(actor: fixture.authorized_actor)

    assert Exception.message(error) =~ "Attempted to update stale record"
  end

  test "an injected failure rolls back state, audit reference, and outbox fact", fixture do
    record = create_record(fixture.tenant_a, fixture.authorized_actor)

    assert {:error, %Ash.Error.Invalid{} = error} =
             record
             |> submission_changeset(fixture.tenant_a)
             |> Ash.Changeset.set_context(%{inject_outbox_failure?: true})
             |> Ash.update(actor: fixture.authorized_actor)

    assert Exception.message(error) =~ "injected failure after transactional outbox insert"

    assert [persisted_record] =
             FoundationRecord
             |> Ash.Query.set_tenant(fixture.tenant_a)
             |> Ash.read!(actor: fixture.authorized_actor)

    assert persisted_record.id == record.id
    assert persisted_record.status == :draft
    assert persisted_record.lock_version == 1
    assert is_nil(persisted_record.audit_reference)
    assert [] == outbox_events(fixture.tenant_a, record.id)
  end

  test "missing correlation and causation context prevents the transition", fixture do
    record = create_record(fixture.tenant_a, fixture.authorized_actor)

    assert {:error, %Ash.Error.Invalid{}} =
             record
             |> Ash.Changeset.for_update(:submit_for_review, %{})
             |> Ash.Changeset.set_tenant(fixture.tenant_a)
             |> Ash.update(actor: fixture.authorized_actor)

    assert [persisted_record] =
             FoundationRecord
             |> Ash.Query.set_tenant(fixture.tenant_a)
             |> Ash.read!(actor: fixture.authorized_actor)

    assert persisted_record.status == :draft
    assert is_nil(persisted_record.audit_reference)
    assert [] == outbox_events(fixture.tenant_a, record.id)
  end

  test "compound foreign keys reject a cross-tenant role assignment", fixture do
    assert_raise PostgrexError, fn ->
      insert_actor_role(fixture.tenant_a, fixture.authorized_actor.id, fixture.other_tenant_role)
    end
  end

  test "the database rejects an empty name through an alternate write", fixture do
    assert_raise PostgrexError, fn ->
      SQL.query!(
        Repo,
        """
        INSERT INTO foundation_records (
          id, tenant_id, name, status, lock_version, inserted_at, updated_at
        )
        VALUES ($1, $2, '', 'draft', 1, NOW(), NOW())
        """,
        [dump_uuid(UUID.generate()), dump_uuid(fixture.tenant_a)]
      )
    end
  end

  test "the database rejects an invalid workflow state through an alternate write", fixture do
    assert_raise PostgrexError, fn ->
      SQL.query!(
        Repo,
        """
        INSERT INTO foundation_records (
          id, tenant_id, name, status, lock_version, inserted_at, updated_at
        )
        VALUES ($1, $2, 'Unsafe state', 'published', 1, NOW(), NOW())
        """,
        [dump_uuid(UUID.generate()), dump_uuid(fixture.tenant_a)]
      )
    end
  end

  defp access_fixture do
    tenant_a = insert_tenant("Synthetic tenant A")
    tenant_b = insert_tenant("Synthetic tenant B")

    authorized_actor = insert_actor(tenant_a, "Authorized actor")
    read_only_actor = insert_actor(tenant_a, "Read-only actor")
    composed_actor = insert_actor(tenant_a, "Composed-role actor")
    other_tenant_actor = insert_actor(tenant_b, "Other-tenant service actor", :service)

    read_a = insert_capability(tenant_a, "foundation_record.read")
    create_a = insert_capability(tenant_a, "foundation_record.create")
    submit_a = insert_capability(tenant_a, "foundation_record.submit_for_review")
    read_b = insert_capability(tenant_b, "foundation_record.read")
    create_b = insert_capability(tenant_b, "foundation_record.create")
    submit_b = insert_capability(tenant_b, "foundation_record.submit_for_review")

    direct_role = insert_role(tenant_a, "Direct transition role")
    read_only_role = insert_role(tenant_a, "Read-only role")
    composed_role = insert_role(tenant_a, "Composable role")
    included_role = insert_role(tenant_a, "Included transition role")
    other_tenant_role = insert_role(tenant_b, "Other tenant role")

    Enum.each([read_a, create_a, submit_a], &insert_role_capability(tenant_a, direct_role, &1))
    insert_role_capability(tenant_a, read_only_role, read_a)

    Enum.each(
      [read_a, create_a, submit_a],
      &insert_role_capability(tenant_a, included_role, &1)
    )

    Enum.each(
      [read_b, create_b, submit_b],
      &insert_role_capability(tenant_b, other_tenant_role, &1)
    )

    insert_role_inclusion(tenant_a, composed_role, included_role)
    insert_actor_role(tenant_a, authorized_actor.id, direct_role)
    insert_actor_role(tenant_a, read_only_actor.id, read_only_role)
    insert_actor_role(tenant_a, composed_actor.id, composed_role)
    insert_actor_role(tenant_b, other_tenant_actor.id, other_tenant_role)

    %{
      tenant_a: tenant_a,
      tenant_b: tenant_b,
      authorized_actor: authorized_actor,
      read_only_actor: read_only_actor,
      composed_actor: composed_actor,
      other_tenant_actor: other_tenant_actor,
      composed_role: composed_role,
      other_tenant_role: other_tenant_role
    }
  end

  defp create_record(tenant_id, actor, name \\ "Synthetic record") do
    FoundationRecord
    |> Ash.Changeset.for_create(:create, %{name: name})
    |> Ash.Changeset.set_tenant(tenant_id)
    |> Ash.create!(actor: actor)
  end

  defp json_api_request(record, options) do
    correlation_id = Keyword.get(options, :correlation_id, UUID.generate())
    causation_id = Keyword.get(options, :causation_id, UUID.generate())
    route = Keyword.get(options, :route, "/foundation-records/#{record.id}/submit-for-review")

    attributes =
      Keyword.get(options, :attributes, %{
        "correlation_id" => correlation_id,
        "causation_id" => causation_id
      })

    body =
      Jason.encode!(%{
        "data" => %{
          "type" => "foundation-record",
          "id" => record.id,
          "attributes" => attributes
        }
      })

    :patch
    |> conn(route, body)
    |> put_req_header("accept", "application/vnd.api+json")
    |> put_req_header("content-type", "application/vnd.api+json")
    |> maybe_set_actor(options[:actor])
    |> maybe_set_tenant(options[:tenant])
    |> Ash.PlugHelpers.set_context(%{
      assurance: :synthetic_test,
      purpose: :phase_0_framework_evaluation,
      correlation_id: correlation_id
    })
    |> JsonApiRouter.call([])
  end

  defp maybe_set_actor(conn, nil), do: conn
  defp maybe_set_actor(conn, actor), do: Ash.PlugHelpers.set_actor(conn, actor)

  defp maybe_set_tenant(conn, nil), do: conn
  defp maybe_set_tenant(conn, tenant), do: Ash.PlugHelpers.set_tenant(conn, tenant)

  defp json_api_error_fingerprint(response, requested_id) do
    response.resp_body
    |> Jason.decode!()
    |> Map.fetch!("errors")
    |> Enum.map(fn error ->
      error
      |> Map.drop(["id"])
      |> Map.update!("detail", &String.replace(&1, requested_id, "<requested-id>"))
    end)
  end

  defp assert_record_remains_draft(record, fixture) do
    assert [persisted_record] =
             FoundationRecord
             |> Ash.Query.set_tenant(fixture.tenant_a)
             |> Ash.read!(actor: fixture.authorized_actor)

    assert persisted_record.id == record.id
    assert persisted_record.status == :draft
    assert persisted_record.lock_version == 1
    assert is_nil(persisted_record.audit_reference)
    assert [] == outbox_events(fixture.tenant_a, record.id)
  end

  defp submit!(record, tenant_id, actor) do
    record
    |> submission_changeset(tenant_id)
    |> Ash.update!(actor: actor)
  end

  defp submission_changeset(
         record,
         tenant_id,
         correlation_id \\ UUID.generate(),
         causation_id \\ UUID.generate()
       ) do
    record
    |> Ash.Changeset.for_update(:submit_for_review, %{
      correlation_id: correlation_id,
      causation_id: causation_id
    })
    |> Ash.Changeset.set_tenant(tenant_id)
  end

  defp outbox_events(tenant_id, record_id) do
    %{rows: rows} =
      SQL.query!(
        Repo,
        """
        SELECT
          id,
          actor_id,
          aggregate_type,
          event_type,
          schema_version,
          correlation_id,
          causation_id,
          audit_reference,
          classification,
          payload
        FROM outbox_events
        WHERE tenant_id = $1 AND aggregate_id = $2
        ORDER BY occurred_at, id
        """,
        [dump_uuid(tenant_id), dump_uuid(record_id)]
      )

    Enum.map(rows, fn [
                        id,
                        actor_id,
                        aggregate_type,
                        event_type,
                        schema_version,
                        correlation_id,
                        causation_id,
                        audit_reference,
                        classification,
                        payload
                      ] ->
      %{
        id: load_uuid(id),
        actor_id: load_uuid(actor_id),
        aggregate_type: aggregate_type,
        event_type: event_type,
        schema_version: schema_version,
        correlation_id: load_uuid(correlation_id),
        causation_id: load_uuid(causation_id),
        audit_reference: load_uuid(audit_reference),
        classification: classification,
        payload: payload
      }
    end)
  end

  defp insert_tenant(name) do
    id = UUID.generate()

    SQL.query!(
      Repo,
      "INSERT INTO tenants (id, name, inserted_at, updated_at) VALUES ($1, $2, NOW(), NOW())",
      [dump_uuid(id), name]
    )

    id
  end

  defp insert_actor(tenant_id, name, kind \\ :human) do
    id = UUID.generate()

    SQL.query!(
      Repo,
      """
      INSERT INTO actors (id, tenant_id, name, kind, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, NOW(), NOW())
      """,
      [dump_uuid(id), dump_uuid(tenant_id), name, Atom.to_string(kind)]
    )

    struct!(Actor, id: id, tenant_id: tenant_id, name: name, kind: kind)
  end

  defp insert_role(tenant_id, name) do
    insert_tenant_scoped_named_record("roles", "name", tenant_id, name)
  end

  defp insert_capability(tenant_id, key) do
    insert_tenant_scoped_named_record("capabilities", "key", tenant_id, key)
  end

  defp insert_tenant_scoped_named_record(table, column, tenant_id, value) do
    id = UUID.generate()

    SQL.query!(
      Repo,
      """
      INSERT INTO #{table} (id, tenant_id, #{column}, inserted_at, updated_at)
      VALUES ($1, $2, $3, NOW(), NOW())
      """,
      [dump_uuid(id), dump_uuid(tenant_id), value]
    )

    id
  end

  defp insert_actor_role(tenant_id, actor_id, role_id) do
    insert_join("actor_roles", tenant_id, "actor_id", actor_id, "role_id", role_id)
  end

  defp insert_role_capability(tenant_id, role_id, capability_id) do
    insert_join(
      "role_capabilities",
      tenant_id,
      "role_id",
      role_id,
      "capability_id",
      capability_id
    )
  end

  defp insert_role_inclusion(tenant_id, role_id, included_role_id) do
    insert_join(
      "role_inclusions",
      tenant_id,
      "role_id",
      role_id,
      "included_role_id",
      included_role_id
    )
  end

  defp insert_join(table, tenant_id, left_column, left_id, right_column, right_id) do
    SQL.query!(
      Repo,
      """
      INSERT INTO #{table} (
        id, tenant_id, #{left_column}, #{right_column}, inserted_at, updated_at
      )
      VALUES ($1, $2, $3, $4, NOW(), NOW())
      """,
      [
        dump_uuid(UUID.generate()),
        dump_uuid(tenant_id),
        dump_uuid(left_id),
        dump_uuid(right_id)
      ]
    )
  end

  defp rename_role(tenant_id, role_id, name) do
    SQL.query!(
      Repo,
      "UPDATE roles SET name = $1, updated_at = NOW() WHERE tenant_id = $2 AND id = $3",
      [name, dump_uuid(tenant_id), dump_uuid(role_id)]
    )
  end

  defp dump_uuid(value), do: UUID.dump!(value)

  defp load_uuid(<<_value::128>> = value), do: UUID.load!(value)
  defp load_uuid(value), do: value
end
