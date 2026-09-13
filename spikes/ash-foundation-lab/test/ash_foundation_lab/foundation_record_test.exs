defmodule AshFoundationLab.FoundationRecordTest do
  use ExUnit.Case, async: true

  alias AshFoundationLab.Actor
  alias AshFoundationLab.FoundationRecord
  alias AshFoundationLab.Repo
  alias Ecto.Adapters.SQL
  alias Ecto.Adapters.SQL.Sandbox
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  setup do
    owner = Sandbox.start_owner!(Repo, shared: false)
    on_exit(fn -> Sandbox.stop_owner(owner) end)

    {:ok, access_fixture()}
  end

  test "an authorized actor reads and performs the named transition", fixture do
    record = create_record(fixture.tenant_a, fixture.authorized_actor)

    assert [visible_record] =
             FoundationRecord
             |> Ash.Query.set_tenant(fixture.tenant_a)
             |> Ash.read!(actor: fixture.authorized_actor)

    assert visible_record.id == record.id

    assert {:ok, submitted} =
             record
             |> Ash.Changeset.for_update(:submit_for_review)
             |> Ash.Changeset.set_tenant(fixture.tenant_a)
             |> Ash.update(actor: fixture.authorized_actor)

    assert submitted.status == :in_review
    assert submitted.lock_version == 2
  end

  test "an actor without the transition capability is denied", fixture do
    record = create_record(fixture.tenant_a, fixture.authorized_actor)

    assert {:error, %Ash.Error.Forbidden{}} =
             record
             |> Ash.Changeset.for_update(:submit_for_review)
             |> Ash.Changeset.set_tenant(fixture.tenant_a)
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
             |> Ash.Changeset.for_update(:submit_for_review)
             |> Ash.Changeset.set_tenant(fixture.tenant_a)
             |> Ash.update(actor: fixture.other_tenant_actor)
  end

  test "renamed and composed tenant roles grant the same capability", fixture do
    rename_role(fixture.tenant_a, fixture.composed_role, "Renamed review circle")

    record = create_record(fixture.tenant_a, fixture.composed_actor)

    assert {:ok, submitted} =
             record
             |> Ash.Changeset.for_update(:submit_for_review)
             |> Ash.Changeset.set_tenant(fixture.tenant_a)
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
             |> Ash.Changeset.for_update(:submit_for_review)
             |> Ash.Changeset.set_tenant(fixture.tenant_a)
             |> Ash.update(actor: fixture.authorized_actor)

    assert Exception.message(error) =~ "record must be in draft state"
  end

  test "a stale transition returns an optimistic-lock conflict", fixture do
    stale_record = create_record(fixture.tenant_a, fixture.authorized_actor)
    _submitted = submit!(stale_record, fixture.tenant_a, fixture.authorized_actor)

    assert {:error, %Ash.Error.Invalid{} = error} =
             stale_record
             |> Ash.Changeset.for_update(:submit_for_review)
             |> Ash.Changeset.set_tenant(fixture.tenant_a)
             |> Ash.update(actor: fixture.authorized_actor)

    assert Exception.message(error) =~ "Attempted to update stale record"
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

  defp create_record(tenant_id, actor) do
    FoundationRecord
    |> Ash.Changeset.for_create(:create, %{name: "Synthetic record"})
    |> Ash.Changeset.set_tenant(tenant_id)
    |> Ash.create!(actor: actor)
  end

  defp submit!(record, tenant_id, actor) do
    record
    |> Ash.Changeset.for_update(:submit_for_review)
    |> Ash.Changeset.set_tenant(tenant_id)
    |> Ash.update!(actor: actor)
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
end
