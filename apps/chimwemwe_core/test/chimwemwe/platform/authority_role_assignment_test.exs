defmodule Chimwemwe.Platform.AuthorityRoleAssignmentTest do
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

  alias Chimwemwe.Platform.Authority.AssignRoleResult
  alias Chimwemwe.Repo
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  @tenant_a "11111111-1111-4111-8111-111111111111"
  @tenant_b "22222222-2222-4222-8222-222222222222"
  @admin_a "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  @admin_a_peer "abababab-abab-4bab-8bab-abababababab"
  @denied_a "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
  @target_a "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
  @admin_b "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
  @target_b "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"
  @assign_capability "platform.authority.assignments.create"
  @result_capability "platform.authority.roles.rename"

  @authority_tables [
    "platform_authority_action_idempotency",
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

  test "commits assignment, audit, outbox, exact replay, and immediate authority", fixture do
    idempotency_key = UUID.generate()
    causation_id = UUID.generate()

    input =
      assign_input(
        fixture.target_membership_a,
        fixture.target_role_a,
        idempotency_key,
        causation_id
      )

    assert {:error, %AuthorityError{code: :forbidden}} =
             Authority.authorize(fixture.runtime, context_target_a(), @result_capability)

    assert {:ok,
            %AssignRoleResult{
              id: assignment_id,
              membership_id: membership_id,
              role_id: role_id,
              lock_version: 1,
              audit_reference: audit_reference,
              event_id: event_id
            } = first} = Authority.assign_role(fixture.runtime, context_admin_a(), input)

    assert membership_id == fixture.target_membership_a
    assert role_id == fixture.target_role_a

    assert {:ok, ^first} =
             Authority.assign_role(fixture.runtime, context_admin_a(UUID.generate()), input)

    assert :ok = Authority.authorize(fixture.runtime, context_target_a(), @result_capability)

    assert {:ok,
            [
              [
                ^membership_id,
                ^role_id,
                1,
                "platform.authority.actor_role_assignment.assign",
                0,
                1,
                %{"membership_id" => ^membership_id, "role_id" => ^role_id},
                "platform.authority.actor_role_assignment.created",
                1,
                %{
                  "lock_version" => 1,
                  "membership_id" => ^membership_id,
                  "role_id" => ^role_id
                },
                "completed",
                %{
                  "assignment_id" => ^assignment_id,
                  "lock_version" => 1,
                  "membership_id" => ^membership_id,
                  "role_id" => ^role_id
                }
              ]
            ]} =
             read_committed_facts(
               fixture.runtime,
               context_admin_a(),
               assignment_id,
               audit_reference,
               event_id,
               idempotency_key
             )
  end

  test "rejects unauthorized, duplicate, cross-tenant, malformed, and alternate writes",
       fixture do
    assert {:error, %AuthorityError{code: :forbidden}} =
             Authority.assign_role(
               fixture.runtime,
               context_denied_a(),
               assign_input(fixture.target_membership_a, fixture.target_role_a)
             )

    assert {:error, %AuthorityError{code: :not_found}} =
             Authority.assign_role(
               fixture.runtime,
               context_admin_a(),
               assign_input(fixture.target_membership_b, fixture.target_role_a)
             )

    assert {:error, %AuthorityError{code: :not_found}} =
             Authority.assign_role(
               fixture.runtime,
               context_admin_a(),
               assign_input(fixture.target_membership_a, fixture.target_role_b)
             )

    assert {:error, %AuthorityError{code: :invalid_input}} =
             Authority.assign_role(
               fixture.runtime,
               context_admin_a(),
               Map.put(
                 assign_input(fixture.target_membership_a, fixture.target_role_a),
                 :tenant_id,
                 @tenant_b
               )
             )

    assert {:error, %ContextError{code: :missing_trusted_context}} =
             Authority.assign_role(
               fixture.runtime,
               %{tenant_id: @tenant_a},
               assign_input(fixture.target_membership_a, fixture.target_role_a)
             )

    assert {:ok, %AssignRoleResult{}} =
             Authority.assign_role(
               fixture.runtime,
               context_admin_a(),
               assign_input(fixture.target_membership_a, fixture.target_role_a)
             )

    assert {:error, %AuthorityError{code: :conflict}} =
             Authority.assign_role(
               fixture.runtime,
               context_admin_a(),
               assign_input(fixture.target_membership_a, fixture.target_role_a)
             )

    assert {:ok, [[1, 1, 1, 1]]} =
             assignment_and_fact_counts(
               fixture.runtime,
               context_admin_a(),
               fixture.target_membership_a,
               fixture.target_role_a
             )

    assert {:ok, :checked} =
             Persistence.with_writer(fixture.runtime, context_admin_a(), fn ->
               cross_tenant_error =
                 assert_raise PostgrexError, fn ->
                   insert_assignment_directly(
                     @tenant_a,
                     fixture.target_membership_b,
                     fixture.target_role_a,
                     1
                   )
                 end

               assert cross_tenant_error.postgres.constraint ==
                        "actor_role_assignments_membership_tenant_fkey"

               version_error =
                 assert_raise PostgrexError, fn ->
                   insert_assignment_directly(
                     @tenant_a,
                     fixture.unassigned_membership_a,
                     fixture.secondary_role_a,
                     0
                   )
                 end

               assert version_error.postgres.constraint ==
                        "platform_actor_role_assignment_version_must_be_positive"

               :checked
             end)
  end

  test "binds an idempotency key to the canonical request and authorized actor", fixture do
    idempotency_key = UUID.generate()
    causation_id = UUID.generate()

    input =
      assign_input(
        fixture.target_membership_a,
        fixture.target_role_a,
        idempotency_key,
        causation_id
      )

    assert {:ok, %AssignRoleResult{} = first} =
             Authority.assign_role(fixture.runtime, context_admin_a(), input)

    assert {:error, %AuthorityError{code: :idempotency_conflict}} =
             Authority.assign_role(
               fixture.runtime,
               context_admin_a(),
               %{input | role_id: fixture.secondary_role_a}
             )

    assert {:error, %AuthorityError{code: :idempotency_conflict}} =
             Authority.assign_role(fixture.runtime, context_admin_a_peer(), input)

    assert {:ok, ^first} = Authority.assign_role(fixture.runtime, context_admin_a(), input)

    assert {:ok, [[1, 1, 1, 1]]} =
             assignment_and_fact_counts(
               fixture.runtime,
               context_admin_a(),
               fixture.target_membership_a,
               fixture.target_role_a
             )
  end

  test "serializes concurrent exact retries into one committed assignment", fixture do
    input = assign_input(fixture.target_membership_a, fixture.target_role_a)
    parent = self()

    tasks =
      for _index <- 1..2 do
        Task.async(fn ->
          send(parent, {:ready, self()})

          receive do
            :go -> Authority.assign_role(fixture.runtime, context_admin_a(), input)
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

    assert {:ok, [[1, 1, 1, 1]]} =
             assignment_and_fact_counts(
               fixture.runtime,
               context_admin_a(),
               fixture.target_membership_a,
               fixture.target_role_a
             )
  end

  test "scopes the same idempotency key independently to each tenant", fixture do
    idempotency_key = UUID.generate()

    assert {:ok, %AssignRoleResult{lock_version: 1}} =
             Authority.assign_role(
               fixture.runtime,
               context_admin_a(),
               assign_input(
                 fixture.target_membership_a,
                 fixture.target_role_a,
                 idempotency_key
               )
             )

    assert {:ok, %AssignRoleResult{lock_version: 1}} =
             Authority.assign_role(
               fixture.runtime,
               context_admin_b(),
               assign_input(
                 fixture.target_membership_b,
                 fixture.target_role_b,
                 idempotency_key
               )
             )

    assert {:ok, [[1, 1, 1, 1]]} =
             assignment_and_fact_counts(
               fixture.runtime,
               context_admin_a(),
               fixture.target_membership_a,
               fixture.target_role_a
             )

    assert {:ok, [[1, 1, 1, 1]]} =
             assignment_and_fact_counts(
               fixture.runtime,
               context_admin_b(),
               fixture.target_membership_b,
               fixture.target_role_b
             )
  end

  test "rolls back assignment and every fact after a post-outbox failure", fixture do
    input = assign_input(fixture.target_membership_a, fixture.target_role_a)
    install_completion_failure(fixture.runtime)

    try do
      assert {:error, %AuthorityError{code: :retryable_dependency}} =
               Authority.assign_role(fixture.runtime, context_admin_a(), input)

      assert {:ok, [[0, 0, 0, 0]]} =
               assignment_and_fact_counts(
                 fixture.runtime,
                 context_admin_a(),
                 fixture.target_membership_a,
                 fixture.target_role_a
               )
    after
      remove_completion_failure(fixture.runtime)
    end

    assert {:ok, %AssignRoleResult{lock_version: 1}} =
             Authority.assign_role(fixture.runtime, context_admin_a(), input)

    assert {:ok, [[1, 1, 1, 1]]} =
             assignment_and_fact_counts(
               fixture.runtime,
               context_admin_a(),
               fixture.target_membership_a,
               fixture.target_role_a
             )
  end

  defp seed_authority(runtime) do
    ids = %{
      admin_role_a: UUID.generate(),
      target_role_a: UUID.generate(),
      secondary_role_a: UUID.generate(),
      admin_role_b: UUID.generate(),
      target_role_b: UUID.generate(),
      assign_capability_a: UUID.generate(),
      result_capability_a: UUID.generate(),
      assign_capability_b: UUID.generate(),
      result_capability_b: UUID.generate(),
      admin_membership_a: UUID.generate(),
      admin_peer_membership_a: UUID.generate(),
      denied_membership_a: UUID.generate(),
      target_membership_a: UUID.generate(),
      unassigned_membership_a: UUID.generate(),
      admin_membership_b: UUID.generate(),
      target_membership_b: UUID.generate()
    }

    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context_admin_a(), fn ->
               insert_membership(ids.admin_membership_a, @tenant_a, @admin_a)
               insert_membership(ids.admin_peer_membership_a, @tenant_a, @admin_a_peer)
               insert_membership(ids.denied_membership_a, @tenant_a, @denied_a)
               insert_membership(ids.target_membership_a, @tenant_a, @target_a)
               insert_membership(ids.unassigned_membership_a, @tenant_a, UUID.generate())
               insert_role(ids.admin_role_a, @tenant_a, "Authority assignment manager")
               insert_role(ids.target_role_a, @tenant_a, "Rename authority")
               insert_role(ids.secondary_role_a, @tenant_a, "Secondary authority")
               insert_capability(ids.assign_capability_a, @tenant_a, @assign_capability)
               insert_capability(ids.result_capability_a, @tenant_a, @result_capability)
               insert_assignment(@tenant_a, ids.admin_membership_a, ids.admin_role_a)
               insert_assignment(@tenant_a, ids.admin_peer_membership_a, ids.admin_role_a)
               insert_grant(@tenant_a, ids.admin_role_a, ids.assign_capability_a)
               insert_grant(@tenant_a, ids.target_role_a, ids.result_capability_a)
               :seeded
             end)

    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context_admin_b(), fn ->
               insert_membership(ids.admin_membership_b, @tenant_b, @admin_b)
               insert_membership(ids.target_membership_b, @tenant_b, @target_b)
               insert_role(ids.admin_role_b, @tenant_b, "Authority assignment manager")
               insert_role(ids.target_role_b, @tenant_b, "Rename authority")
               insert_capability(ids.assign_capability_b, @tenant_b, @assign_capability)
               insert_capability(ids.result_capability_b, @tenant_b, @result_capability)
               insert_assignment(@tenant_b, ids.admin_membership_b, ids.admin_role_b)
               insert_grant(@tenant_b, ids.admin_role_b, ids.assign_capability_b)
               insert_grant(@tenant_b, ids.target_role_b, ids.result_capability_b)
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
    insert_assignment_directly(tenant_id, membership_id, role_id, 1)
  end

  defp insert_assignment_directly(tenant_id, membership_id, role_id, lock_version) do
    Repo.query!(
      """
      INSERT INTO platform_actor_role_assignments
        (id, tenant_id, membership_id, role_id, lock_version, inserted_at)
      VALUES ($1, $2, $3, $4, $5, NOW())
      """,
      [
        dump(UUID.generate()),
        dump(tenant_id),
        dump(membership_id),
        dump(role_id),
        lock_version
      ]
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

  defp read_committed_facts(runtime, context, assignment_id, audit_reference, event_id, key) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT
          assignment.membership_id::text,
          assignment.role_id::text,
          assignment.lock_version,
          audit.action_name,
          audit.before_version,
          audit.after_version,
          audit.change_summary,
          outbox.event_type,
          outbox.schema_version,
          outbox.payload,
          claim.status,
          claim.result_payload
        FROM platform_actor_role_assignments AS assignment
        JOIN platform_authority_audit_events AS audit
          ON audit.tenant_id = assignment.tenant_id AND audit.aggregate_id = assignment.id
        JOIN platform_outbox_events AS outbox
          ON outbox.tenant_id = audit.tenant_id AND outbox.audit_reference = audit.id
        JOIN platform_authority_action_idempotency AS claim
          ON claim.tenant_id = audit.tenant_id AND claim.audit_reference = audit.id
        WHERE assignment.tenant_id = $1
          AND assignment.id = $2
          AND audit.id = $3
          AND outbox.id = $4
          AND claim.idempotency_key = $5
        """,
        Enum.map(
          [
            TrustedActor.tenant_id(context.actor),
            assignment_id,
            audit_reference,
            event_id,
            key
          ],
          &dump/1
        )
      ).rows
    end)
  end

  defp assignment_and_fact_counts(runtime, context, membership_id, role_id) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT
          (SELECT count(*) FROM platform_actor_role_assignments AS assignment
           WHERE assignment.tenant_id = $1
             AND assignment.membership_id = $2
             AND assignment.role_id = $3),
          (SELECT count(*) FROM platform_authority_audit_events AS audit
           WHERE audit.tenant_id = $1
             AND audit.action_name = 'platform.authority.actor_role_assignment.assign'),
          (SELECT count(*) FROM platform_outbox_events AS outbox
           WHERE outbox.tenant_id = $1
             AND outbox.event_type = 'platform.authority.actor_role_assignment.created'),
          (SELECT count(*) FROM platform_authority_action_idempotency AS claim
           WHERE claim.tenant_id = $1
             AND claim.action_name = 'platform.authority.actor_role_assignment.assign')
        """,
        Enum.map(
          [TrustedActor.tenant_id(context.actor), membership_id, role_id],
          &dump/1
        )
      ).rows
    end)
  end

  defp install_completion_failure(runtime) do
    assert {:ok, :installed} =
             Persistence.with_writer(runtime, context_admin_a(), fn ->
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
             Persistence.with_writer(runtime, context_admin_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_authority_idempotency_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_authority_idempotency_completion()")
               :removed
             end)
  end

  defp clear_tenants(runtime) do
    for context <- [context_admin_a(), context_admin_b()] do
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

  defp assign_input(
         membership_id,
         role_id,
         idempotency_key \\ UUID.generate(),
         causation_id \\ UUID.generate()
       ) do
    %{
      membership_id: membership_id,
      role_id: role_id,
      idempotency_key: idempotency_key,
      causation_id: causation_id
    }
  end

  defp runtime_options do
    [
      repositories: [pooled: [log: false, pool: DBConnection.ConnectionPool, pool_size: 4]],
      placements: [
        placement(@tenant_a, "pooled-authority-assignment", :pooled),
        placement(@tenant_b, "pooled-authority-assignment", :pooled)
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

  defp context_admin_a(correlation_id \\ UUID.generate()),
    do: context(@admin_a, @tenant_a, correlation_id)

  defp context_admin_a_peer,
    do: context(@admin_a_peer, @tenant_a, UUID.generate())

  defp context_denied_a,
    do: context(@denied_a, @tenant_a, UUID.generate())

  defp context_target_a,
    do: context(@target_a, @tenant_a, UUID.generate())

  defp context_admin_b,
    do: context(@admin_b, @tenant_b, UUID.generate())

  defp context(actor_id, tenant_id, correlation_id) do
    {:ok, actor} =
      TrustedActor.establish(actor_id: actor_id, tenant_id: tenant_id, assurance: "mfa")

    {:ok, placement} =
      TrustedPlacement.establish(
        tenant_id: tenant_id,
        routing_version: 7,
        profile: :pooled,
        placement_ref: "pooled-authority-assignment"
      )

    {:ok, context} =
      ExecutionContext.establish(
        actor,
        placement,
        correlation_id: correlation_id,
        purpose: "platform.authority.actor_role_assignment.assign",
        locale: "en"
      )

    context
  end

  defp dump(uuid), do: UUID.dump!(uuid)
end
