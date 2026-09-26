defmodule Chimwemwe.Platform.AuthorityRoleRenameTest do
  use ExUnit.Case, async: false

  alias Chimwemwe.Platform.{
    Authority,
    AuthorityError,
    ContextError,
    ExecutionContext,
    Persistence,
    PersistenceRuntime,
    TrustedActor,
    TrustedPlacement
  }

  alias Chimwemwe.Platform.Authority.RenameRoleResult
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @tenant_a "11111111-1111-4111-8111-111111111111"
  @tenant_b "22222222-2222-4222-8222-222222222222"
  @actor_a "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  @actor_a_peer "abababab-abab-4bab-8bab-abababababab"
  @actor_a_denied "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
  @actor_b "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
  @rename_capability "platform.authority.roles.rename"

  @authority_tables [
    "platform_authority_action_idempotency",
    "platform_outbox_consumer_receipts",
    "platform_outbox_deliveries",
    "platform_outbox_events",
    "platform_authority_audit_events",
    "platform_role_inclusions",
    "platform_role_capability_grants",
    "platform_actor_role_assignments",
    "platform_capabilities",
    "platform_roles",
    "platform_tenant_memberships"
  ]

  setup do
    runtime = start_supervised!({PersistenceRuntime, runtime_options()})
    clear_tenants(runtime)
    fixture = seed_authority(runtime)
    {:ok, Map.put(fixture, :runtime, runtime)}
  end

  test "commits role state, audit, outbox, and exact replay as one result", fixture do
    idempotency_key = UUID.generate()
    causation_id = UUID.generate()
    first_context = context_a(UUID.generate())

    input =
      rename_input(
        fixture.role_a,
        "  Renamed tenant circle  ",
        1,
        idempotency_key,
        causation_id
      )

    assert {:ok,
            %RenameRoleResult{
              id: role_id,
              name: "Renamed tenant circle",
              lock_version: 2,
              audit_reference: audit_reference,
              event_id: event_id
            } = first} = Authority.rename_role(fixture.runtime, first_context, input)

    assert role_id == fixture.role_a

    assert {:ok, ^first} =
             Authority.rename_role(fixture.runtime, context_a(UUID.generate()), input)

    assert {:ok,
            [
              [
                "Renamed tenant circle",
                2,
                "platform.authority.role.rename",
                1,
                2,
                %{"from_name" => "Tenant circle", "to_name" => "Renamed tenant circle"},
                "platform.authority.role.renamed",
                1,
                %{"lock_version" => 2},
                "completed",
                "Renamed tenant circle",
                2
              ]
            ]} =
             read_committed_facts(
               fixture.runtime,
               context_a(),
               fixture.role_a,
               audit_reference,
               event_id,
               idempotency_key
             )

    assert :ok = Authority.authorize(fixture.runtime, context_a(), @rename_capability)
  end

  test "rejects unauthorized, stale, duplicate-name, cross-tenant, and malformed requests",
       fixture do
    assert {:error, %AuthorityError{code: :forbidden}} =
             Authority.rename_role(
               fixture.runtime,
               context_a_denied(),
               rename_input(fixture.role_a, "Denied", 1)
             )

    assert {:error, %AuthorityError{code: :conflict}} =
             Authority.rename_role(
               fixture.runtime,
               context_a(),
               rename_input(fixture.role_a, "Stale", 2)
             )

    assert {:error, %AuthorityError{code: :conflict}} =
             Authority.rename_role(
               fixture.runtime,
               context_a(),
               rename_input(fixture.role_a, "Authority manager", 1)
             )

    assert {:error, %AuthorityError{code: :not_found}} =
             Authority.rename_role(
               fixture.runtime,
               context_a(),
               rename_input(fixture.role_b, "Cross tenant", 1)
             )

    assert {:error, %AuthorityError{code: :invalid_input}} =
             Authority.rename_role(
               fixture.runtime,
               context_a(),
               Map.put(rename_input(fixture.role_a, "Unexpected", 1), :tenant_id, @tenant_b)
             )

    assert {:error, %ContextError{code: :missing_trusted_context}} =
             Authority.rename_role(
               fixture.runtime,
               %{tenant_id: @tenant_a},
               rename_input(fixture.role_a, "Raw context", 1)
             )

    assert {:ok, [["Tenant circle", 1, 0, 0, 0]]} =
             state_and_fact_counts(fixture.runtime, context_a(), fixture.role_a)
  end

  test "binds an idempotency key to the canonical request and authorized actor", fixture do
    idempotency_key = UUID.generate()
    causation_id = UUID.generate()
    input = rename_input(fixture.role_a, "Committed name", 1, idempotency_key, causation_id)

    assert {:ok, %RenameRoleResult{} = first} =
             Authority.rename_role(fixture.runtime, context_a(), input)

    assert {:error, %AuthorityError{code: :idempotency_conflict}} =
             Authority.rename_role(
               fixture.runtime,
               context_a(),
               %{input | name: "Changed request"}
             )

    assert {:error, %AuthorityError{code: :idempotency_conflict}} =
             Authority.rename_role(fixture.runtime, context_a_peer(), input)

    assert {:ok, ^first} = Authority.rename_role(fixture.runtime, context_a(), input)

    assert {:ok, [["Committed name", 2, 1, 1, 1]]} =
             state_and_fact_counts(fixture.runtime, context_a(), fixture.role_a)
  end

  test "serializes concurrent exact retries into one committed transition", fixture do
    input = rename_input(fixture.role_a, "Concurrent rename", 1)
    parent = self()

    tasks =
      for _index <- 1..2 do
        Task.async(fn ->
          send(parent, {:ready, self()})

          receive do
            :go -> Authority.rename_role(fixture.runtime, context_a(), input)
          end
        end)
      end

    task_pids =
      for _index <- 1..2 do
        assert_receive {:ready, task_pid}
        task_pid
      end

    Enum.each(task_pids, &send(&1, :go))

    assert [{:ok, first}, {:ok, second}] = Enum.map(tasks, &Task.await(&1, 10_000))
    assert first == second

    assert {:ok, [["Concurrent rename", 2, 1, 1, 1]]} =
             state_and_fact_counts(fixture.runtime, context_a(), fixture.role_a)
  end

  test "scopes the same idempotency key independently to each tenant", fixture do
    idempotency_key = UUID.generate()

    assert {:ok, %RenameRoleResult{lock_version: 2}} =
             Authority.rename_role(
               fixture.runtime,
               context_a(),
               rename_input(fixture.role_a, "Tenant A renamed", 1, idempotency_key)
             )

    assert {:ok, %RenameRoleResult{lock_version: 2}} =
             Authority.rename_role(
               fixture.runtime,
               context_b(),
               rename_input(fixture.role_b, "Tenant B renamed", 1, idempotency_key)
             )

    assert {:ok, [["Tenant A renamed", 2, 1, 1, 1]]} =
             state_and_fact_counts(fixture.runtime, context_a(), fixture.role_a)

    assert {:ok, [["Tenant B renamed", 2, 1, 1, 1]]} =
             state_and_fact_counts(fixture.runtime, context_b(), fixture.role_b)
  end

  test "rolls back state and every fact after a post-outbox database failure", fixture do
    input = rename_input(fixture.role_a, "Retry after rollback", 1)
    install_completion_failure(fixture.runtime)

    try do
      assert {:error, %AuthorityError{code: :retryable_dependency}} =
               Authority.rename_role(fixture.runtime, context_a(), input)

      assert {:ok, [["Tenant circle", 1, 0, 0, 0]]} =
               state_and_fact_counts(fixture.runtime, context_a(), fixture.role_a)
    after
      remove_completion_failure(fixture.runtime)
    end

    assert {:ok, %RenameRoleResult{lock_version: 2}} =
             Authority.rename_role(fixture.runtime, context_a(), input)

    assert {:ok, [["Retry after rollback", 2, 1, 1, 1]]} =
             state_and_fact_counts(fixture.runtime, context_a(), fixture.role_a)
  end

  defp seed_authority(runtime) do
    ids = %{
      manager_role_a: UUID.generate(),
      role_a: UUID.generate(),
      role_b: UUID.generate(),
      manager_role_b: UUID.generate(),
      capability_a: UUID.generate(),
      capability_b: UUID.generate(),
      membership_a: UUID.generate(),
      membership_a_peer: UUID.generate(),
      membership_a_denied: UUID.generate(),
      membership_b: UUID.generate()
    }

    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context_a(), fn ->
               insert_membership(ids.membership_a, @tenant_a, @actor_a)
               insert_membership(ids.membership_a_peer, @tenant_a, @actor_a_peer)
               insert_membership(ids.membership_a_denied, @tenant_a, @actor_a_denied)
               insert_role(ids.manager_role_a, @tenant_a, "Authority manager")
               insert_role(ids.role_a, @tenant_a, "Tenant circle")
               insert_capability(ids.capability_a, @tenant_a, @rename_capability)
               insert_assignment(@tenant_a, ids.membership_a, ids.manager_role_a)
               insert_assignment(@tenant_a, ids.membership_a_peer, ids.manager_role_a)
               insert_grant(@tenant_a, ids.manager_role_a, ids.capability_a)
               :seeded
             end)

    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context_b(), fn ->
               insert_membership(ids.membership_b, @tenant_b, @actor_b)
               insert_role(ids.manager_role_b, @tenant_b, "Authority manager")
               insert_role(ids.role_b, @tenant_b, "Tenant B circle")
               insert_capability(ids.capability_b, @tenant_b, @rename_capability)
               insert_assignment(@tenant_b, ids.membership_b, ids.manager_role_b)
               insert_grant(@tenant_b, ids.manager_role_b, ids.capability_b)
               :seeded
             end)

    ids
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

  defp insert_role(id, tenant_id, name) do
    Repo.query!(
      """
      INSERT INTO platform_roles
        (id, tenant_id, name, lock_version, inserted_at, updated_at)
      VALUES ($1, $2, $3, 1, NOW(), NOW())
      """,
      [dump(id), dump(tenant_id), name]
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
        (id, tenant_id, membership_id, role_id, inserted_at)
      VALUES ($1, $2, $3, $4, NOW())
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

  defp read_committed_facts(runtime, context, role_id, audit_reference, event_id, key) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT
          role.name,
          role.lock_version,
          audit.action_name,
          audit.before_version,
          audit.after_version,
          audit.change_summary,
          outbox.event_type,
          outbox.schema_version,
          outbox.payload,
          claim.status,
          claim.result_name,
          claim.result_lock_version
        FROM platform_roles AS role
        JOIN platform_authority_audit_events AS audit
          ON audit.tenant_id = role.tenant_id AND audit.aggregate_id = role.id
        JOIN platform_outbox_events AS outbox
          ON outbox.tenant_id = audit.tenant_id AND outbox.audit_reference = audit.id
        JOIN platform_authority_action_idempotency AS claim
          ON claim.tenant_id = audit.tenant_id AND claim.audit_reference = audit.id
        WHERE role.tenant_id = $1
          AND role.id = $2
          AND audit.id = $3
          AND outbox.id = $4
          AND claim.idempotency_key = $5
        """,
        Enum.map(
          [
            TrustedActor.tenant_id(context.actor),
            role_id,
            audit_reference,
            event_id,
            key
          ],
          &dump/1
        )
      ).rows
    end)
  end

  defp state_and_fact_counts(runtime, context, role_id) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT
          role.name,
          role.lock_version,
          (SELECT count(*) FROM platform_authority_audit_events AS audit
           WHERE audit.tenant_id = role.tenant_id AND audit.aggregate_id = role.id),
          (SELECT count(*) FROM platform_outbox_events AS outbox
           WHERE outbox.tenant_id = role.tenant_id AND outbox.aggregate_id = role.id),
          (SELECT count(*) FROM platform_authority_action_idempotency AS claim
           WHERE claim.tenant_id = role.tenant_id AND claim.aggregate_id = role.id)
        FROM platform_roles AS role
        WHERE role.tenant_id = $1 AND role.id = $2
        """,
        [dump(TrustedActor.tenant_id(context.actor)), dump(role_id)]
      ).rows
    end)
  end

  defp install_completion_failure(runtime) do
    assert {:ok, :installed} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_authority_idempotency_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_authority_idempotency_completion()")

               Repo.query!("""
               CREATE FUNCTION test_fail_authority_idempotency_completion()
               RETURNS trigger
               LANGUAGE plpgsql
               AS $$
               BEGIN
                 IF NEW.status = 'completed' THEN
                   RAISE EXCEPTION USING
                     ERRCODE = '40001',
                     MESSAGE = 'synthetic completion failure';
                 END IF;

                 RETURN NEW;
               END;
               $$;
               """)

               Repo.query!("""
               CREATE TRIGGER test_fail_authority_idempotency_completion
               BEFORE UPDATE OF status
               ON platform_authority_action_idempotency
               FOR EACH ROW
               EXECUTE FUNCTION test_fail_authority_idempotency_completion();
               """)

               :installed
             end)
  end

  defp remove_completion_failure(runtime) do
    assert {:ok, :removed} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_authority_idempotency_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_authority_idempotency_completion()")
               :removed
             end)
  end

  defp clear_tenants(runtime) do
    for context <- [context_a(), context_b()] do
      assert {:ok, :cleared} = clear_tenant(runtime, context)
    end
  end

  defp clear_tenant(runtime, context) do
    Persistence.with_writer(runtime, context, fn ->
      tenant_id = TrustedActor.tenant_id(context.actor)

      for table <- @authority_tables do
        Repo.query!("DELETE FROM #{table} WHERE tenant_id = $1", [dump(tenant_id)])
      end

      :cleared
    end)
  end

  defp rename_input(
         role_id,
         name,
         expected_version,
         idempotency_key \\ UUID.generate(),
         causation_id \\ UUID.generate()
       ) do
    %{
      role_id: role_id,
      name: name,
      expected_version: expected_version,
      idempotency_key: idempotency_key,
      causation_id: causation_id
    }
  end

  defp runtime_options do
    [
      repositories: [pooled: [log: false, pool: DBConnection.ConnectionPool, pool_size: 4]],
      placements: [
        placement(@tenant_a, "pooled-authority-write", :pooled),
        placement(@tenant_b, "pooled-authority-write", :pooled)
      ],
      per_tenant_limit: 4,
      per_placement_limit: 8
    ]
  end

  defp placement(tenant_id, placement_ref, repository) do
    [
      tenant_id: tenant_id,
      routing_version: 7,
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
        routing_version: 7,
        profile: :pooled,
        placement_ref: "pooled-authority-write"
      )

    {:ok, context} =
      ExecutionContext.establish(
        actor,
        placement,
        correlation_id: correlation_id,
        purpose: "platform.authority.role.rename",
        locale: "en"
      )

    context
  end

  defp dump(uuid), do: UUID.dump!(uuid)
end
