defmodule Chimwemwe.OrganizationLegal.FoundationTest do
  use ExUnit.Case, async: false

  alias Chimwemwe.OrganizationLegal.{ActionResult, Error, Foundation, LegalEntityView}

  alias Chimwemwe.Platform.{
    ContextError,
    ExecutionContext,
    Persistence,
    PersistenceRuntime,
    ResourceContract,
    TrustedActor,
    TrustedPlacement
  }

  alias Chimwemwe.Platform.ModuleLifecycle.ReleaseManifest
  alias Chimwemwe.Repo
  alias Ecto.UUID

  @tenant_a "31313131-3131-4131-8131-313131313131"
  @tenant_b "32323232-3232-4232-8232-323232323232"
  @actor_a "a1a1a1a1-a1a1-41a1-81a1-a1a1a1a1a1a1"
  @actor_a_peer "a2a2a2a2-a2a2-42a2-82a2-a2a2a2a2a2a2"
  @actor_a_denied "a3a3a3a3-a3a3-43a3-83a3-a3a3a3a3a3a3"
  @actor_b "b1b1b1b1-b1b1-41b1-81b1-b1b1b1b1b1b1"
  @module_key "organization.legal"
  @manage_capability "organization.legal.entities.manage"
  @read_capability "organization.legal.entities.read"
  @register_action "organization.legal.entity.register"
  @revise_action "organization.legal.entity.profile.revise"

  setup do
    runtime = start_supervised!({PersistenceRuntime, runtime_options()})
    clear_fixture(runtime)
    fixture = seed_foundation(runtime)
    {:ok, Map.put(fixture, :runtime, runtime)}
  end

  test "declares the bounded module and valid tenant-owned resources" do
    assert {:ok, %{version: "1.0.0", dependencies: []}} =
             Foundation.release_manifest()
             |> ReleaseManifest.fetch(@module_key)

    assert :ok = ResourceContract.validate_domain(Chimwemwe.OrganizationLegal)
  end

  test "registers one entity with immutable profile, audit, outbox, and exact read", fixture do
    input = register_input("  Mphamvu Education Operations Limited  ", "  Mphamvu Operations  ")

    assert {:ok,
            %ActionResult{
              id: entity_id,
              status: :active,
              lock_version: 1,
              audit_reference: audit_reference,
              event_id: event_id
            } = first} = Foundation.register_legal_entity(fixture.runtime, context_a(), input)

    assert {:ok, ^first} =
             Foundation.register_legal_entity(fixture.runtime, context_a(UUID.generate()), input)

    assert {:ok,
            %LegalEntityView{
              id: ^entity_id,
              official_name: "Mphamvu Education Operations Limited",
              display_name: "Mphamvu Operations",
              status: :active,
              lock_version: 1,
              recorded_at: %DateTime{}
            }} = Foundation.current_legal_entity(fixture.runtime, context_a(), entity_id)

    assert {:ok,
            [
              [
                "active",
                1,
                1,
                "Mphamvu Education Operations Limited",
                "Mphamvu Operations",
                @register_action,
                0,
                1,
                %{"changed_fields" => ["display_name", "official_name"]},
                "organization.legal.entity.registered",
                %{
                  "legal_entity_id" => ^entity_id,
                  "lock_version" => 1,
                  "status" => "active"
                },
                "completed"
              ]
            ]} =
             read_committed_facts(
               fixture.runtime,
               context_a(),
               entity_id,
               audit_reference,
               event_id,
               input.idempotency_key
             )
  end

  test "revises by expected version while preserving identity and earlier history", fixture do
    assert {:ok, registered} =
             Foundation.register_legal_entity(
               fixture.runtime,
               context_a(),
               register_input("Mphamvu Education Operations Limited", "Mphamvu Operations")
             )

    revision =
      revise_input(
        registered.id,
        1,
        "Mphamvu Learning Operations Limited",
        "Mphamvu Learning"
      )

    assert {:ok, %ActionResult{id: entity_id, lock_version: 2} = revised} =
             Foundation.revise_legal_entity_profile(fixture.runtime, context_a(), revision)

    assert entity_id == registered.id

    assert {:ok, ^revised} =
             Foundation.revise_legal_entity_profile(
               fixture.runtime,
               context_a(UUID.generate()),
               revision
             )

    assert {:ok,
            %LegalEntityView{
              id: ^entity_id,
              official_name: "Mphamvu Learning Operations Limited",
              display_name: "Mphamvu Learning",
              lock_version: 2
            }} = Foundation.current_legal_entity(fixture.runtime, context_a(), entity_id)

    assert {:ok,
            [
              [1, "Mphamvu Education Operations Limited", "Mphamvu Operations"],
              [2, "Mphamvu Learning Operations Limited", "Mphamvu Learning"]
            ]} = profile_history(fixture.runtime, context_a(), entity_id)

    assert {:error, %Error{code: :conflict}} =
             Foundation.revise_legal_entity_profile(
               fixture.runtime,
               context_a(),
               revise_input(
                 entity_id,
                 2,
                 "Mphamvu Learning Operations Limited",
                 "Mphamvu Learning"
               )
             )
  end

  test "denies absent authority, missing context, cross-tenant identifiers, and malformed input",
       fixture do
    assert {:error, %Error{code: :forbidden}} =
             Foundation.register_legal_entity(
               fixture.runtime,
               context_a_denied(),
               register_input("Denied Legal Entity", "Denied")
             )

    assert {:error, %ContextError{code: :missing_trusted_context}} =
             Foundation.register_legal_entity(
               fixture.runtime,
               %{tenant_id: @tenant_a},
               register_input("Raw Context Entity", "Raw context")
             )

    assert {:ok, tenant_b_entity} =
             Foundation.register_legal_entity(
               fixture.runtime,
               context_b(),
               register_input("Tenant B Legal Entity", "Tenant B")
             )

    assert {:error, %Error{code: :not_found}} =
             Foundation.current_legal_entity(fixture.runtime, context_a(), tenant_b_entity.id)

    assert {:error, %Error{code: :not_found}} =
             Foundation.revise_legal_entity_profile(
               fixture.runtime,
               context_a(),
               revise_input(tenant_b_entity.id, 1, "Cross Tenant", "Cross tenant")
             )

    assert {:error, %Error{code: :invalid_input}} =
             Foundation.register_legal_entity(
               fixture.runtime,
               context_a(),
               Map.put(register_input("Unexpected", "Unexpected"), :tenant_id, @tenant_b)
             )

    assert {:error, %Error{code: :invalid_input}} =
             Foundation.current_legal_entity(fixture.runtime, context_a(), "not-a-uuid")

    assert {:ok, [[0, 0, 0]]} = fact_counts(fixture.runtime, context_a())
  end

  test "binds idempotency to normalized request, action, actor, and tenant", fixture do
    idempotency_key = UUID.generate()
    input = register_input("Bound Entity", "Bound", idempotency_key)

    assert {:ok, %ActionResult{} = first} =
             Foundation.register_legal_entity(fixture.runtime, context_a(), input)

    assert {:error, %Error{code: :idempotency_conflict}} =
             Foundation.register_legal_entity(
               fixture.runtime,
               context_a(),
               %{input | display_name: "Changed replay"}
             )

    assert {:error, %Error{code: :idempotency_conflict}} =
             Foundation.register_legal_entity(fixture.runtime, context_a_peer(), input)

    assert {:ok, %ActionResult{id: tenant_b_id}} =
             Foundation.register_legal_entity(fixture.runtime, context_b(), input)

    refute tenant_b_id == first.id

    assert {:ok, [[1, 1, 1]]} = fact_counts(fixture.runtime, context_a())
    assert {:ok, [[1, 1, 1]]} = fact_counts(fixture.runtime, context_b())
  end

  test "serializes concurrent revisions and rejects the stale contender", fixture do
    assert {:ok, registered} =
             Foundation.register_legal_entity(
               fixture.runtime,
               context_a(),
               register_input("Concurrent Entity", "Concurrent")
             )

    parent = self()

    tasks =
      for {official_name, display_name} <- [
            {"Concurrent Entity Alpha", "Alpha"},
            {"Concurrent Entity Beta", "Beta"}
          ] do
        Task.async(fn ->
          send(parent, {:ready, self()})

          receive do
            :go ->
              Foundation.revise_legal_entity_profile(
                fixture.runtime,
                context_a(),
                revise_input(registered.id, 1, official_name, display_name)
              )
          end
        end)
      end

    task_pids =
      for _index <- 1..2 do
        assert_receive {:ready, task_pid}
        task_pid
      end

    Enum.each(task_pids, &send(&1, :go))
    results = Enum.map(tasks, &Task.await(&1, 10_000))

    assert 1 == Enum.count(results, &match?({:ok, %ActionResult{lock_version: 2}}, &1))
    assert 1 == Enum.count(results, &match?({:error, %Error{code: :stale}}, &1))

    assert {:ok, [[2]]} = profile_count(fixture.runtime, context_a(), registered.id)
  end

  test "rolls back entity, profile, audit, and outbox after a late database failure", fixture do
    input = register_input("Rollback Entity", "Rollback")
    install_completion_failure(fixture.runtime)

    try do
      assert {:error, %Error{code: :retryable_dependency}} =
               Foundation.register_legal_entity(fixture.runtime, context_a(), input)

      assert {:ok, [[0, 0, 0]]} = fact_counts(fixture.runtime, context_a())
      assert {:ok, [[0, 0]]} = entity_and_profile_counts(fixture.runtime, context_a())
    after
      remove_completion_failure(fixture.runtime)
    end

    assert {:ok, %ActionResult{lock_version: 1}} =
             Foundation.register_legal_entity(fixture.runtime, context_a(), input)
  end

  test "fails closed when the module is inactive and retains committed state", fixture do
    assert {:ok, registered} =
             Foundation.register_legal_entity(
               fixture.runtime,
               context_a(),
               register_input("Retained Entity", "Retained")
             )

    deactivate_module(fixture.runtime, context_a())

    assert {:error, %Error{code: :module_unavailable}} =
             Foundation.register_legal_entity(
               fixture.runtime,
               context_a(),
               register_input("Inactive Module Entity", "Inactive")
             )

    assert {:error, %Error{code: :module_unavailable}} =
             Foundation.current_legal_entity(fixture.runtime, context_a(), registered.id)

    assert {:ok, [[1, 1]]} = entity_and_profile_counts(fixture.runtime, context_a())
  end

  test "database constraints reject cross-tenant profile links and identity/history mutation",
       fixture do
    assert {:ok, registered_a} =
             Foundation.register_legal_entity(
               fixture.runtime,
               context_a(),
               register_input("Constraint Entity A", "Constraint A")
             )

    assert {:ok, registered_b} =
             Foundation.register_legal_entity(
               fixture.runtime,
               context_b(),
               register_input("Constraint Entity B", "Constraint B")
             )

    assert_postgres_error(fn ->
      Persistence.with_writer(fixture.runtime, context_a(), fn ->
        Repo.query!(
          """
          INSERT INTO organization_legal_entity_profile_revisions (
            id, tenant_id, legal_entity_id, revision_number, official_name,
            display_name, recorded_by_actor_id, recorded_at, inserted_at
          )
          VALUES ($1, $2, $3, 99, 'Cross tenant', 'Cross tenant', $4, NOW(), NOW())
          """,
          Enum.map([UUID.generate(), @tenant_a, registered_b.id, @actor_a], &dump/1)
        )
      end)
    end)

    assert_postgres_error(fn ->
      Persistence.with_writer(fixture.runtime, context_a(), fn ->
        Repo.query!(
          """
          UPDATE organization_legal_entity_profile_revisions
          SET display_name = 'Mutated history'
          WHERE tenant_id = $1 AND legal_entity_id = $2 AND revision_number = 1
          """,
          [dump(@tenant_a), dump(registered_a.id)]
        )
      end)
    end)

    assert_postgres_error(fn ->
      Persistence.with_writer(fixture.runtime, context_a(), fn ->
        Repo.query!(
          """
          UPDATE organization_legal_entities
          SET tenant_id = $1
          WHERE tenant_id = $2 AND id = $3
          """,
          [dump(@tenant_b), dump(@tenant_a), dump(registered_a.id)]
        )
      end)
    end)
  end

  defp seed_foundation(runtime) do
    ids = %{
      membership_a: UUID.generate(),
      membership_a_peer: UUID.generate(),
      membership_a_denied: UUID.generate(),
      membership_b: UUID.generate(),
      role_a: UUID.generate(),
      role_b: UUID.generate(),
      manage_capability_a: UUID.generate(),
      read_capability_a: UUID.generate(),
      manage_capability_b: UUID.generate(),
      read_capability_b: UUID.generate()
    }

    seed_tenant(
      runtime,
      context_a(),
      @tenant_a,
      [
        {ids.membership_a, @actor_a, true},
        {ids.membership_a_peer, @actor_a_peer, true},
        {ids.membership_a_denied, @actor_a_denied, false}
      ],
      ids.role_a,
      ids.manage_capability_a,
      ids.read_capability_a
    )

    seed_tenant(
      runtime,
      context_b(),
      @tenant_b,
      [{ids.membership_b, @actor_b, true}],
      ids.role_b,
      ids.manage_capability_b,
      ids.read_capability_b
    )

    ids
  end

  defp seed_tenant(
         runtime,
         context,
         tenant_id,
         memberships,
         role_id,
         manage_capability_id,
         read_capability_id
       ) do
    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context, fn ->
               insert_role(role_id, tenant_id)

               Enum.each(
                 memberships,
                 &seed_membership(&1, tenant_id, role_id)
               )

               insert_capability(manage_capability_id, tenant_id, @manage_capability)
               insert_capability(read_capability_id, tenant_id, @read_capability)
               insert_grant(tenant_id, role_id, manage_capability_id)
               insert_grant(tenant_id, role_id, read_capability_id)
               insert_active_module(tenant_id)
               :seeded
             end)
  end

  defp seed_membership({membership_id, actor_id, assigned?}, tenant_id, role_id) do
    insert_membership(membership_id, tenant_id, actor_id)
    if assigned?, do: insert_assignment(tenant_id, membership_id, role_id)
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

  defp insert_role(id, tenant_id) do
    Repo.query!(
      """
      INSERT INTO platform_roles
        (id, tenant_id, name, lock_version, inserted_at, updated_at)
      VALUES ($1, $2, 'Legal structure manager', 1, NOW(), NOW())
      """,
      Enum.map([id, tenant_id], &dump/1)
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
        (id, tenant_id, membership_id, role_id, lock_version, inserted_at)
      VALUES ($1, $2, $3, $4, 1, NOW())
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

  defp insert_active_module(tenant_id) do
    entitlement_id = UUID.generate()

    Repo.query!(
      """
      INSERT INTO platform_module_entitlements (id, tenant_id, module_key, inserted_at)
      VALUES ($1, $2, $3, NOW())
      """,
      [dump(entitlement_id), dump(tenant_id), @module_key]
    )

    Repo.query!(
      """
      INSERT INTO platform_module_activations (
        id, tenant_id, entitlement_id, module_version, state, lock_version,
        activated_at, inserted_at, updated_at
      )
      VALUES ($1, $2, $3, '1.0.0', 'active', 1, NOW(), NOW(), NOW())
      """,
      Enum.map([UUID.generate(), tenant_id, entitlement_id], &dump/1)
    )
  end

  defp deactivate_module(runtime, context) do
    assert {:ok, :deactivated} =
             Persistence.with_writer(runtime, context, fn ->
               Repo.query!(
                 """
                 UPDATE platform_module_activations AS activation
                 SET state = 'inactive',
                     lock_version = lock_version + 1,
                     deactivated_at = NOW(),
                     replay_from_cursor = consumer_cursor,
                     projection_ready = false,
                     reconciliation_required = true,
                     updated_at = NOW()
                 FROM platform_module_entitlements AS entitlement
                 WHERE entitlement.tenant_id = activation.tenant_id
                   AND entitlement.id = activation.entitlement_id
                   AND activation.tenant_id = $1
                   AND entitlement.module_key = $2
                 """,
                 [dump(TrustedActor.tenant_id(context.actor)), @module_key]
               )

               :deactivated
             end)
  end

  defp read_committed_facts(runtime, context, entity_id, audit_reference, event_id, key) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT entity.status, entity.lock_version, profile.revision_number,
               profile.official_name, profile.display_name,
               audit.action_name, audit.before_version, audit.after_version,
               audit.change_summary, outbox.event_type, outbox.payload, claim.status
        FROM organization_legal_entities AS entity
        JOIN organization_legal_entity_profile_revisions AS profile
          ON profile.tenant_id = entity.tenant_id
         AND profile.legal_entity_id = entity.id
         AND profile.revision_number = entity.lock_version
        JOIN platform_authority_audit_events AS audit
          ON audit.tenant_id = entity.tenant_id AND audit.aggregate_id = entity.id
        JOIN platform_outbox_events AS outbox
          ON outbox.tenant_id = audit.tenant_id AND outbox.audit_reference = audit.id
        JOIN platform_authority_action_idempotency AS claim
          ON claim.tenant_id = audit.tenant_id AND claim.audit_reference = audit.id
        WHERE entity.tenant_id = $1 AND entity.id = $2
          AND audit.id = $3 AND outbox.id = $4 AND claim.idempotency_key = $5
        """,
        Enum.map(
          [
            TrustedActor.tenant_id(context.actor),
            entity_id,
            audit_reference,
            event_id,
            key
          ],
          &dump/1
        )
      ).rows
    end)
  end

  defp profile_history(runtime, context, entity_id) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT revision_number, official_name, display_name
        FROM organization_legal_entity_profile_revisions
        WHERE tenant_id = $1 AND legal_entity_id = $2
        ORDER BY revision_number
        """,
        [dump(TrustedActor.tenant_id(context.actor)), dump(entity_id)]
      ).rows
    end)
  end

  defp profile_count(runtime, context, entity_id) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT count(*)
        FROM organization_legal_entity_profile_revisions
        WHERE tenant_id = $1 AND legal_entity_id = $2
        """,
        [dump(TrustedActor.tenant_id(context.actor)), dump(entity_id)]
      ).rows
    end)
  end

  defp fact_counts(runtime, context) do
    Persistence.with_writer(runtime, context, fn ->
      tenant_id = dump(TrustedActor.tenant_id(context.actor))

      Repo.query!(
        """
        SELECT
          (SELECT count(*) FROM platform_authority_audit_events
           WHERE tenant_id = $1 AND action_name IN ($2, $3)),
          (SELECT count(*) FROM platform_outbox_events
           WHERE tenant_id = $1 AND aggregate_type = 'organization.legal.entity'),
          (SELECT count(*) FROM platform_authority_action_idempotency
           WHERE tenant_id = $1 AND action_name IN ($2, $3))
        """,
        [tenant_id, @register_action, @revise_action]
      ).rows
    end)
  end

  defp entity_and_profile_counts(runtime, context) do
    Persistence.with_writer(runtime, context, fn ->
      tenant_id = dump(TrustedActor.tenant_id(context.actor))

      Repo.query!(
        """
        SELECT
          (SELECT count(*) FROM organization_legal_entities WHERE tenant_id = $1),
          (SELECT count(*) FROM organization_legal_entity_profile_revisions WHERE tenant_id = $1)
        """,
        [tenant_id]
      ).rows
    end)
  end

  defp install_completion_failure(runtime) do
    assert {:ok, :installed} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_organization_legal_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_organization_legal_completion()")

               Repo.query!("""
               CREATE FUNCTION test_fail_organization_legal_completion()
               RETURNS trigger
               LANGUAGE plpgsql
               AS $$
               BEGIN
                 IF NEW.status = 'completed' AND
                    NEW.action_name LIKE 'organization.legal.%' THEN
                   RAISE EXCEPTION USING
                     ERRCODE = '40001',
                     MESSAGE = 'synthetic legal entity completion failure';
                 END IF;

                 RETURN NEW;
               END;
               $$;
               """)

               Repo.query!("""
               CREATE TRIGGER test_fail_organization_legal_completion
               BEFORE UPDATE OF status
               ON platform_authority_action_idempotency
               FOR EACH ROW
               EXECUTE FUNCTION test_fail_organization_legal_completion();
               """)

               :installed
             end)
  end

  defp remove_completion_failure(runtime) do
    assert {:ok, :removed} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_organization_legal_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_organization_legal_completion()")
               :removed
             end)
  end

  defp clear_fixture(runtime) do
    assert {:ok, :cleared} =
             Persistence.with_writer(runtime, context_a(), fn ->
               Repo.query!(
                 "TRUNCATE organization_legal_entity_profile_revisions, organization_legal_entities"
               )

               :cleared
             end)

    Enum.each([context_a(), context_b()], fn context ->
      assert {:ok, :cleared} = clear_tenant(runtime, context)
    end)
  end

  defp clear_tenant(runtime, context) do
    Persistence.with_writer(runtime, context, fn ->
      tenant_id = dump(TrustedActor.tenant_id(context.actor))

      for table <- [
            "platform_governed_extension_definitions",
            "platform_authority_action_idempotency",
            "platform_outbox_consumer_receipts",
            "platform_outbox_deliveries",
            "platform_outbox_events",
            "platform_authority_audit_events",
            "platform_module_work_items",
            "platform_module_activations",
            "platform_module_entitlements",
            "platform_role_inclusions",
            "platform_role_capability_grants",
            "platform_actor_role_assignments",
            "platform_capabilities",
            "platform_roles",
            "platform_tenant_memberships"
          ] do
        Repo.query!("DELETE FROM #{table} WHERE tenant_id = $1", [tenant_id])
      end

      :cleared
    end)
  end

  defp register_input(
         official_name,
         display_name,
         idempotency_key \\ UUID.generate(),
         causation_id \\ UUID.generate()
       ) do
    %{
      official_name: official_name,
      display_name: display_name,
      idempotency_key: idempotency_key,
      causation_id: causation_id
    }
  end

  defp revise_input(
         legal_entity_id,
         expected_version,
         official_name,
         display_name,
         idempotency_key \\ UUID.generate(),
         causation_id \\ UUID.generate()
       ) do
    %{
      legal_entity_id: legal_entity_id,
      expected_version: expected_version,
      official_name: official_name,
      display_name: display_name,
      idempotency_key: idempotency_key,
      causation_id: causation_id
    }
  end

  defp runtime_options do
    [
      repositories: [pooled: [log: false, pool: DBConnection.ConnectionPool, pool_size: 6]],
      placements: [
        placement(@tenant_a, "pooled-organization-legal", :pooled),
        placement(@tenant_b, "pooled-organization-legal", :pooled)
      ],
      per_tenant_limit: 6,
      per_placement_limit: 12
    ]
  end

  defp placement(tenant_id, placement_ref, repository) do
    [
      tenant_id: tenant_id,
      routing_version: 9,
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
        routing_version: 9,
        profile: :pooled,
        placement_ref: "pooled-organization-legal"
      )

    {:ok, context} =
      ExecutionContext.establish(
        actor,
        placement,
        correlation_id: correlation_id,
        purpose: "organization.legal.entity",
        locale: "en"
      )

    context
  end

  defp assert_postgres_error(operation) do
    assert_raise Postgrex.Error, operation
  end

  defp dump(uuid), do: UUID.dump!(uuid)
end
