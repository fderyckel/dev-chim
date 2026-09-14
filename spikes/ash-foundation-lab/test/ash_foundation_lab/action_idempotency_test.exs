defmodule AshFoundationLab.ActionIdempotencyTest do
  use ExUnit.Case, async: false

  alias AshFoundationLab.Actor
  alias AshFoundationLab.FoundationRecord
  alias AshFoundationLab.Repo
  alias DBConnection.ConnectionPool
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  setup_all do
    config =
      Repo.config()
      |> Keyword.put(:pool, ConnectionPool)
      |> Keyword.put(:pool_size, 4)

    {:ok, primary_repository} = Repo.start_link(Keyword.put(config, :name, nil))
    {:ok, secondary_repository} = Repo.start_link(Keyword.put(config, :name, nil))
    Process.unlink(primary_repository)
    Process.unlink(secondary_repository)

    on_exit(fn ->
      Enum.each([secondary_repository, primary_repository], fn repository ->
        if Process.alive?(repository), do: GenServer.stop(repository)
      end)
    end)

    {:ok, primary_repository: primary_repository, secondary_repository: secondary_repository}
  end

  setup fixture do
    Repo.put_dynamic_repo(fixture.primary_repository)
    {:ok, Map.merge(fixture, action_fixture())}
  end

  test "concurrent exact retries serialize to one state change, claim, and outbox fact",
       fixture do
    parent = self()
    idempotency_key = UUID.generate()
    correlation_id = UUID.generate()
    causation_id = UUID.generate()

    first =
      Task.async(fn ->
        Repo.put_dynamic_repo(fixture.primary_repository)

        fixture.record
        |> submission_changeset(idempotency_key, correlation_id, causation_id)
        |> Ash.Changeset.set_context(%{
          after_idempotency_claim: fn ->
            send(parent, :first_claim_acquired)

            receive do
              :release_first_claim -> :ok
            end
          end
        })
        |> Ash.update(actor: fixture.actor)
      end)

    assert_receive :first_claim_acquired

    second =
      Task.async(fn ->
        Repo.put_dynamic_repo(fixture.secondary_repository)

        fixture.record
        |> submission_changeset(idempotency_key, correlation_id, causation_id)
        |> Ash.update(actor: fixture.actor)
      end)

    assert Task.yield(second, 100) == nil
    send(first.pid, :release_first_claim)

    assert {:ok, first_result} = Task.await(first)
    assert {:ok, second_result} = Task.await(second)
    assert first_result.id == second_result.id
    assert first_result.status == :in_review
    assert first_result.lock_version == 2
    assert first_result.audit_reference == second_result.audit_reference
    assert count_rows("action_idempotency_keys", fixture.tenant_id) == 1
    assert count_rows("outbox_events", fixture.tenant_id) == 1

    assert [["completed", 2, audit_reference]] =
             Repo.query!(
               """
               SELECT status, result_lock_version, result_audit_reference::text
               FROM action_idempotency_keys
               WHERE tenant_id = $1 AND idempotency_key = $2
               """,
               [dump_uuid(fixture.tenant_id), dump_uuid(idempotency_key)]
             ).rows

    assert audit_reference == first_result.audit_reference
  end

  test "database constraints reject cross-tenant and malformed alternate claims", fixture do
    other_tenant_id = insert_tenant("Other idempotency tenant")
    other_actor = insert_actor(other_tenant_id, "Other idempotency actor")

    cross_tenant_error =
      assert_raise PostgrexError, fn ->
        insert_claim_directly(
          fixture.tenant_id,
          other_actor.id,
          fixture.record.id,
          UUID.generate(),
          :crypto.strong_rand_bytes(32)
        )
      end

    assert cross_tenant_error.postgres.constraint ==
             "action_idempotency_keys_actor_tenant_fkey"

    hash_error =
      assert_raise PostgrexError, fn ->
        insert_claim_directly(
          fixture.tenant_id,
          fixture.actor.id,
          fixture.record.id,
          UUID.generate(),
          <<0>>
        )
      end

    assert hash_error.postgres.constraint == "action_idempotency_request_hash_must_be_sha256"
    assert count_rows("action_idempotency_keys", fixture.tenant_id) == 0
  end

  defp action_fixture do
    tenant_id = insert_tenant("Concurrent idempotency tenant")
    actor = insert_actor(tenant_id, "Concurrent idempotency actor")
    role_id = insert_named("roles", "name", tenant_id, "Concurrent action role")

    for capability <- [
          "foundation_record.create",
          "foundation_record.read",
          "foundation_record.submit_for_review",
          "foundation_record.audit_reference.read"
        ] do
      capability_id = insert_named("capabilities", "key", tenant_id, capability)

      insert_join(
        "role_capabilities",
        tenant_id,
        "role_id",
        role_id,
        "capability_id",
        capability_id
      )
    end

    insert_join("actor_roles", tenant_id, "actor_id", actor.id, "role_id", role_id)

    record =
      FoundationRecord
      |> Ash.Changeset.for_create(:create, %{name: "Concurrent idempotency record"})
      |> Ash.Changeset.set_tenant(tenant_id)
      |> Ash.create!(actor: actor)

    %{tenant_id: tenant_id, actor: actor, record: record}
  end

  defp submission_changeset(record, idempotency_key, correlation_id, causation_id) do
    record
    |> Ash.Changeset.for_update(:submit_for_review, %{
      expected_version: record.lock_version,
      idempotency_key: idempotency_key,
      correlation_id: correlation_id,
      causation_id: causation_id
    })
    |> Ash.Changeset.set_tenant(record.tenant_id)
  end

  defp insert_tenant(name) do
    id = UUID.generate()

    Repo.query!(
      "INSERT INTO tenants (id, name, inserted_at, updated_at) VALUES ($1, $2, NOW(), NOW())",
      [dump_uuid(id), name]
    )

    id
  end

  defp insert_actor(tenant_id, name) do
    id = UUID.generate()

    Repo.query!(
      """
      INSERT INTO actors (id, tenant_id, name, kind, inserted_at, updated_at)
      VALUES ($1, $2, $3, 'human', NOW(), NOW())
      """,
      [dump_uuid(id), dump_uuid(tenant_id), name]
    )

    struct!(Actor, id: id, tenant_id: tenant_id, name: name, kind: :human)
  end

  defp insert_named(table, column, tenant_id, value) do
    id = UUID.generate()

    Repo.query!(
      """
      INSERT INTO #{table} (id, tenant_id, #{column}, inserted_at, updated_at)
      VALUES ($1, $2, $3, NOW(), NOW())
      """,
      [dump_uuid(id), dump_uuid(tenant_id), value]
    )

    id
  end

  defp insert_join(table, tenant_id, left_column, left_id, right_column, right_id) do
    Repo.query!(
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

  defp insert_claim_directly(tenant_id, actor_id, aggregate_id, idempotency_key, hash) do
    Repo.query!(
      """
      INSERT INTO action_idempotency_keys (
        id,
        tenant_id,
        actor_id,
        action_name,
        idempotency_key,
        aggregate_type,
        aggregate_id,
        request_hash,
        status,
        inserted_at,
        updated_at
      )
      VALUES ($1, $2, $3, 'foundation_record.submit_for_review', $4,
        'foundation_record', $5, $6, 'started', NOW(), NOW())
      """,
      [
        dump_uuid(UUID.generate()),
        dump_uuid(tenant_id),
        dump_uuid(actor_id),
        dump_uuid(idempotency_key),
        dump_uuid(aggregate_id),
        hash
      ]
    )
  end

  defp count_rows(table, tenant_id) do
    [[count]] =
      Repo.query!("SELECT count(*) FROM #{table} WHERE tenant_id = $1", [
        dump_uuid(tenant_id)
      ]).rows

    count
  end

  defp dump_uuid(uuid), do: UUID.dump!(uuid)
end
