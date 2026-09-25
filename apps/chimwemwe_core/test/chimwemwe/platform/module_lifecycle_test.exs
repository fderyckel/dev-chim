defmodule Chimwemwe.Platform.ModuleLifecycleTest do
  use ExUnit.Case, async: false

  alias Chimwemwe.Platform.{
    ContextError,
    ExecutionContext,
    ModuleLifecycle,
    ModuleLifecycleError,
    Persistence,
    PersistenceRuntime,
    TrustedActor,
    TrustedPlacement
  }

  alias Chimwemwe.Platform.ModuleLifecycle.{ActivateModuleResult, ReleaseManifest}
  alias Chimwemwe.Repo
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  @tenant_a "11111111-1111-4111-8111-111111111111"
  @tenant_b "22222222-2222-4222-8222-222222222222"
  @admin_a "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  @admin_a_peer "abababab-abab-4bab-8bab-abababababab"
  @denied_a "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
  @admin_b "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
  @activate_capability "platform.modules.activate"
  @use_capability "platform.qualification.use"
  @base_module "platform.qualification.base"
  @dependent_module "platform.qualification.feature"
  @action_name "platform.module_lifecycle.activate"

  @tables [
    "platform_authority_action_idempotency",
    "platform_outbox_events",
    "platform_authority_audit_events",
    "platform_module_activations",
    "platform_module_entitlements",
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

  test "release manifest rejects duplicate, missing, and cyclic declarations" do
    assert {:ok, manifest} = ReleaseManifest.new(release_declarations())

    assert {:ok, %{version: "1.0.0", dependencies: [@base_module]}} =
             ReleaseManifest.fetch(manifest, @dependent_module)

    assert {:error, :invalid_manifest} =
             ReleaseManifest.new([
               declaration(@base_module),
               declaration(@base_module)
             ])

    assert {:error, :invalid_manifest} =
             ReleaseManifest.new([
               declaration(@dependent_module, ["platform.qualification.missing"])
             ])

    assert {:error, :invalid_manifest} =
             ReleaseManifest.new([
               declaration(@base_module, [@dependent_module]),
               declaration(@dependent_module, [@base_module])
             ])

    assert {:error, :invalid_manifest} =
             ReleaseManifest.new([declaration("invalid")])

    assert {:error, :invalid_manifest} =
             ReleaseManifest.new([
               Map.put(declaration(@base_module), :version, "version-one")
             ])
  end

  test "keeps release, entitlement, activation, and actor capability independent", fixture do
    manifest = release_manifest()
    base_only_manifest = release_manifest([declaration(@base_module)])

    assert {:error, %ModuleLifecycleError{code: :module_not_released}} =
             ModuleLifecycle.authorize(
               fixture.runtime,
               base_only_manifest,
               context_admin_a(),
               @dependent_module,
               @use_capability
             )

    assert {:error, %ModuleLifecycleError{code: :module_not_entitled}} =
             ModuleLifecycle.authorize(
               fixture.runtime,
               manifest,
               context_admin_a(),
               @base_module,
               @use_capability
             )

    entitlement_id = add_entitlement(fixture.runtime, context_admin_a(), @base_module)

    assert {:error, %ModuleLifecycleError{code: :module_inactive}} =
             ModuleLifecycle.authorize(
               fixture.runtime,
               manifest,
               context_admin_a(),
               @base_module,
               @use_capability
             )

    assert {:ok, %ActivateModuleResult{module_key: @base_module, lock_version: 1}} =
             ModuleLifecycle.activate(
               fixture.runtime,
               manifest,
               context_admin_a(),
               activate_input(@base_module)
             )

    assert {:error, %ModuleLifecycleError{code: :forbidden}} =
             ModuleLifecycle.authorize(
               fixture.runtime,
               manifest,
               context_admin_a(),
               @base_module,
               @use_capability
             )

    grant_use_capability(fixture.runtime, context_admin_a(), fixture)

    assert :ok =
             ModuleLifecycle.authorize(
               fixture.runtime,
               manifest,
               context_admin_a(),
               @base_module,
               @use_capability
             )

    dependent_entitlement_id =
      add_entitlement(fixture.runtime, context_admin_a(), @dependent_module)

    assert {:ok, %ActivateModuleResult{module_key: @dependent_module, lock_version: 1}} =
             ModuleLifecycle.activate(
               fixture.runtime,
               manifest,
               context_admin_a(),
               activate_input(@dependent_module)
             )

    assert :ok =
             ModuleLifecycle.authorize(
               fixture.runtime,
               manifest,
               context_admin_a(),
               @dependent_module,
               @use_capability
             )

    assert {:ok, [[^entitlement_id, "1.0.0", "active", 1]]} =
             read_activation(fixture.runtime, context_admin_a(), @base_module)

    assert {:ok, [[^dependent_entitlement_id, "1.0.0", "active", 1]]} =
             read_activation(fixture.runtime, context_admin_a(), @dependent_module)
  end

  test "commits activation evidence, replays exactly, and binds actor and request", fixture do
    manifest = release_manifest()
    add_entitlement(fixture.runtime, context_admin_a(), @base_module)
    idempotency_key = UUID.generate()
    causation_id = UUID.generate()
    input = activate_input(@base_module, idempotency_key, causation_id)

    assert {:ok,
            %ActivateModuleResult{
              id: activation_id,
              module_key: @base_module,
              module_version: "1.0.0",
              lock_version: 1,
              audit_reference: audit_reference,
              event_id: event_id
            } = first} =
             ModuleLifecycle.activate(fixture.runtime, manifest, context_admin_a(), input)

    assert {:ok, ^first} =
             ModuleLifecycle.activate(
               fixture.runtime,
               manifest,
               context_admin_a(UUID.generate()),
               input
             )

    assert {:error, %ModuleLifecycleError{code: :idempotency_conflict}} =
             ModuleLifecycle.activate(
               fixture.runtime,
               manifest,
               context_admin_a(),
               %{input | causation_id: UUID.generate()}
             )

    assert {:error, %ModuleLifecycleError{code: :idempotency_conflict}} =
             ModuleLifecycle.activate(
               fixture.runtime,
               manifest,
               context_admin_a_peer(),
               input
             )

    assert {:ok,
            [
              [
                "1.0.0",
                "active",
                1,
                @action_name,
                0,
                1,
                %{
                  "module_key" => @base_module,
                  "module_version" => "1.0.0",
                  "state" => "active"
                },
                "platform.module.activated",
                %{
                  "lock_version" => 1,
                  "module_key" => @base_module,
                  "module_version" => "1.0.0"
                },
                "completed",
                %{
                  "activation_id" => ^activation_id,
                  "lock_version" => 1,
                  "module_key" => @base_module,
                  "module_version" => "1.0.0"
                }
              ]
            ]} =
             read_committed_facts(
               fixture.runtime,
               context_admin_a(),
               activation_id,
               audit_reference,
               event_id,
               idempotency_key
             )
  end

  test "denies missing dependencies, capability, context, forged input, and cross-tenant edges",
       fixture do
    manifest = release_manifest()
    add_entitlement(fixture.runtime, context_admin_a(), @dependent_module)

    assert {:error, %ModuleLifecycleError{code: :required_dependency_inactive}} =
             ModuleLifecycle.activate(
               fixture.runtime,
               manifest,
               context_admin_a(),
               activate_input(@dependent_module)
             )

    assert {:error, %ModuleLifecycleError{code: :forbidden}} =
             ModuleLifecycle.activate(
               fixture.runtime,
               manifest,
               context_denied_a(),
               activate_input(@dependent_module)
             )

    assert {:error, %ModuleLifecycleError{code: :invalid_input}} =
             ModuleLifecycle.activate(
               fixture.runtime,
               manifest,
               context_admin_a(),
               Map.put(activate_input(@dependent_module), :tenant_id, @tenant_b)
             )

    assert {:error, %ContextError{code: :missing_trusted_context}} =
             ModuleLifecycle.activate(
               fixture.runtime,
               manifest,
               %{tenant_id: @tenant_a},
               activate_input(@dependent_module)
             )

    entitlement_b = add_entitlement(fixture.runtime, context_admin_b(), @base_module)

    assert {:ok, :checked} =
             Persistence.with_writer(fixture.runtime, context_admin_a(), fn ->
               error =
                 assert_raise PostgrexError, fn ->
                   insert_activation_directly(@tenant_a, entitlement_b, "1.0.0", 1)
                 end

               assert error.postgres.constraint ==
                        "platform_module_activations_entitlement_tenant_fkey"

               key_error =
                 assert_raise PostgrexError, fn ->
                   insert_entitlement(@tenant_a, "invalid")
                 end

               assert key_error.postgres.constraint ==
                        "platform_module_entitlement_key_must_be_valid"

               malformed_version_entitlement =
                 insert_entitlement(@tenant_a, "platform.qualification.malformed_version")

               version_error =
                 assert_raise PostgrexError, fn ->
                   insert_activation_directly(
                     @tenant_a,
                     malformed_version_entitlement,
                     "version-one",
                     1
                   )
                 end

               assert version_error.postgres.constraint ==
                        "platform_module_activation_version_must_be_valid"

               invalid_state_entitlement =
                 insert_entitlement(@tenant_a, "platform.qualification.invalid_state")

               state_error =
                 assert_raise PostgrexError, fn ->
                   insert_activation_directly(
                     @tenant_a,
                     invalid_state_entitlement,
                     "1.0.0",
                     1,
                     "inactive"
                   )
                 end

               assert state_error.postgres.constraint ==
                        "platform_module_activation_state_must_be_active"

               invalid_lock_entitlement =
                 insert_entitlement(@tenant_a, "platform.qualification.invalid_lock")

               lock_error =
                 assert_raise PostgrexError, fn ->
                   insert_activation_directly(
                     @tenant_a,
                     invalid_lock_entitlement,
                     "1.0.0",
                     0
                   )
                 end

               assert lock_error.postgres.constraint ==
                        "platform_module_activation_lock_version_must_be_positive"

               :checked
             end)
  end

  test "serializes exact retries and isolates one idempotency key between tenants", fixture do
    manifest = release_manifest()
    add_entitlement(fixture.runtime, context_admin_a(), @base_module)
    add_entitlement(fixture.runtime, context_admin_b(), @base_module)
    key = UUID.generate()
    input = activate_input(@base_module, key, UUID.generate())

    tasks =
      for _index <- 1..2 do
        Task.async(fn ->
          ModuleLifecycle.activate(fixture.runtime, manifest, context_admin_a(), input)
        end)
      end

    assert [{:ok, first}, {:ok, second}] = Enum.map(tasks, &Task.await(&1, 5_000))
    assert first == second

    assert {:ok, tenant_b_result} =
             ModuleLifecycle.activate(fixture.runtime, manifest, context_admin_b(), input)

    refute first.id == tenant_b_result.id

    assert {:ok, [[1, 1, 1, 1]]} =
             activation_and_fact_counts(fixture.runtime, context_admin_a(), @base_module)

    assert {:ok, [[1, 1, 1, 1]]} =
             activation_and_fact_counts(fixture.runtime, context_admin_b(), @base_module)
  end

  test "rolls back activation and every fact after a post-outbox failure", fixture do
    manifest = release_manifest()
    add_entitlement(fixture.runtime, context_admin_a(), @base_module)
    input = activate_input(@base_module)
    install_completion_failure(fixture.runtime)

    on_exit(fn -> remove_completion_failure(fixture.runtime) end)

    assert {:error, %ModuleLifecycleError{code: :retryable_dependency}} =
             ModuleLifecycle.activate(fixture.runtime, manifest, context_admin_a(), input)

    assert {:ok, [[0, 0, 0, 0]]} =
             activation_and_fact_counts(fixture.runtime, context_admin_a(), @base_module)

    remove_completion_failure(fixture.runtime)

    assert {:ok, %ActivateModuleResult{}} =
             ModuleLifecycle.activate(fixture.runtime, manifest, context_admin_a(), input)

    assert {:ok, [[1, 1, 1, 1]]} =
             activation_and_fact_counts(fixture.runtime, context_admin_a(), @base_module)
  end

  defp release_manifest(declarations \\ release_declarations()) do
    {:ok, manifest} = ReleaseManifest.new(declarations)
    manifest
  end

  defp release_declarations do
    [
      declaration(@base_module),
      declaration(@dependent_module, [@base_module])
    ]
  end

  defp declaration(key, dependencies \\ []) do
    %{key: key, version: "1.0.0", owner: "Platform engineering", dependencies: dependencies}
  end

  defp seed_authority(runtime) do
    ids = %{
      admin_role_a: UUID.generate(),
      admin_role_b: UUID.generate(),
      activate_capability_a: UUID.generate(),
      activate_capability_b: UUID.generate(),
      use_capability_a: UUID.generate(),
      admin_membership_a: UUID.generate(),
      admin_peer_membership_a: UUID.generate(),
      denied_membership_a: UUID.generate(),
      admin_membership_b: UUID.generate()
    }

    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context_admin_a(), fn ->
               insert_membership(ids.admin_membership_a, @tenant_a, @admin_a)
               insert_membership(ids.admin_peer_membership_a, @tenant_a, @admin_a_peer)
               insert_membership(ids.denied_membership_a, @tenant_a, @denied_a)
               insert_role(ids.admin_role_a, @tenant_a, "Module lifecycle manager")
               insert_capability(ids.activate_capability_a, @tenant_a, @activate_capability)
               insert_capability(ids.use_capability_a, @tenant_a, @use_capability)
               insert_assignment(@tenant_a, ids.admin_membership_a, ids.admin_role_a)
               insert_assignment(@tenant_a, ids.admin_peer_membership_a, ids.admin_role_a)
               insert_grant(@tenant_a, ids.admin_role_a, ids.activate_capability_a)
               :seeded
             end)

    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context_admin_b(), fn ->
               insert_membership(ids.admin_membership_b, @tenant_b, @admin_b)
               insert_role(ids.admin_role_b, @tenant_b, "Module lifecycle manager")
               insert_capability(ids.activate_capability_b, @tenant_b, @activate_capability)
               insert_assignment(@tenant_b, ids.admin_membership_b, ids.admin_role_b)
               insert_grant(@tenant_b, ids.admin_role_b, ids.activate_capability_b)
               :seeded
             end)

    ids
  end

  defp grant_use_capability(runtime, context, fixture) do
    assert {:ok, :granted} =
             Persistence.with_writer(runtime, context, fn ->
               insert_grant(@tenant_a, fixture.admin_role_a, fixture.use_capability_a)
               :granted
             end)
  end

  defp add_entitlement(runtime, context, module_key) do
    assert {:ok, entitlement_id} =
             Persistence.with_writer(runtime, context, fn ->
               insert_entitlement(TrustedActor.tenant_id(context.actor), module_key)
             end)

    entitlement_id
  end

  defp insert_entitlement(tenant_id, module_key) do
    id = UUID.generate()

    Repo.query!(
      """
      INSERT INTO platform_module_entitlements (id, tenant_id, module_key, inserted_at)
      VALUES ($1, $2, $3, NOW())
      """,
      [dump(id), dump(tenant_id), module_key]
    )

    id
  end

  defp insert_activation_directly(
         tenant_id,
         entitlement_id,
         module_version,
         lock_version,
         state \\ "active"
       ) do
    Repo.query!(
      """
      INSERT INTO platform_module_activations
        (id, tenant_id, entitlement_id, module_version, state, lock_version,
         activated_at, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW(), NOW())
      """,
      [
        dump(UUID.generate()),
        dump(tenant_id),
        dump(entitlement_id),
        module_version,
        state,
        lock_version
      ]
    )
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

  defp read_activation(runtime, context, module_key) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT activation.entitlement_id::text, activation.module_version,
               activation.state, activation.lock_version
        FROM platform_module_activations AS activation
        JOIN platform_module_entitlements AS entitlement
          ON entitlement.tenant_id = activation.tenant_id
         AND entitlement.id = activation.entitlement_id
        WHERE activation.tenant_id = $1 AND entitlement.module_key = $2
        """,
        [dump(TrustedActor.tenant_id(context.actor)), module_key]
      ).rows
    end)
  end

  defp read_committed_facts(runtime, context, activation_id, audit_reference, event_id, key) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT
          activation.module_version,
          activation.state,
          activation.lock_version,
          audit.action_name,
          audit.before_version,
          audit.after_version,
          audit.change_summary,
          outbox.event_type,
          outbox.payload,
          claim.status,
          claim.result_payload
        FROM platform_module_activations AS activation
        JOIN platform_authority_audit_events AS audit
          ON audit.tenant_id = activation.tenant_id AND audit.aggregate_id = activation.id
        JOIN platform_outbox_events AS outbox
          ON outbox.tenant_id = audit.tenant_id AND outbox.audit_reference = audit.id
        JOIN platform_authority_action_idempotency AS claim
          ON claim.tenant_id = audit.tenant_id AND claim.audit_reference = audit.id
        WHERE activation.tenant_id = $1
          AND activation.id = $2
          AND audit.id = $3
          AND outbox.id = $4
          AND claim.idempotency_key = $5
        """,
        Enum.map(
          [
            TrustedActor.tenant_id(context.actor),
            activation_id,
            audit_reference,
            event_id,
            key
          ],
          &dump/1
        )
      ).rows
    end)
  end

  defp activation_and_fact_counts(runtime, context, module_key) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT
          (SELECT count(*)
           FROM platform_module_activations AS activation
           JOIN platform_module_entitlements AS entitlement
             ON entitlement.tenant_id = activation.tenant_id
            AND entitlement.id = activation.entitlement_id
           WHERE activation.tenant_id = $1 AND entitlement.module_key = $2),
          (SELECT count(*) FROM platform_authority_audit_events AS audit
           WHERE audit.tenant_id = $1 AND audit.action_name = $3),
          (SELECT count(*) FROM platform_outbox_events AS outbox
           WHERE outbox.tenant_id = $1 AND outbox.event_type = 'platform.module.activated'),
          (SELECT count(*) FROM platform_authority_action_idempotency AS claim
           WHERE claim.tenant_id = $1 AND claim.action_name = $3)
        """,
        [dump(TrustedActor.tenant_id(context.actor)), module_key, @action_name]
      ).rows
    end)
  end

  defp install_completion_failure(runtime) do
    assert {:ok, :installed} =
             Persistence.with_writer(runtime, context_admin_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_fail_module_idempotency_completion ON platform_authority_action_idempotency"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_fail_module_idempotency_completion()")

               Repo.query!("""
               CREATE FUNCTION test_fail_module_idempotency_completion()
               RETURNS trigger
               LANGUAGE plpgsql
               AS $$
               BEGIN
                 IF NEW.status = 'completed'
                    AND NEW.action_name = 'platform.module_lifecycle.activate' THEN
                   RAISE EXCEPTION USING
                     ERRCODE = '40001',
                     MESSAGE = 'synthetic module completion failure';
                 END IF;

                 RETURN NEW;
               END;
               $$;
               """)

               Repo.query!("""
               CREATE TRIGGER test_fail_module_idempotency_completion
               BEFORE UPDATE OF status
               ON platform_authority_action_idempotency
               FOR EACH ROW
               EXECUTE FUNCTION test_fail_module_idempotency_completion();
               """)

               :installed
             end)
  end

  defp remove_completion_failure(runtime) do
    Persistence.with_writer(runtime, context_admin_a(), fn ->
      Repo.query!(
        "DROP TRIGGER IF EXISTS test_fail_module_idempotency_completion ON platform_authority_action_idempotency"
      )

      Repo.query!("DROP FUNCTION IF EXISTS test_fail_module_idempotency_completion()")
      :removed
    end)
  end

  defp clear_tenants(runtime) do
    for context <- [context_admin_a(), context_admin_b()] do
      clear_tenant(runtime, context)
    end
  end

  defp clear_tenant(runtime, context) do
    assert {:ok, :cleared} =
             Persistence.with_writer(runtime, context, fn ->
               tenant_id = TrustedActor.tenant_id(context.actor)

               for table <- @tables do
                 Repo.query!("DELETE FROM #{table} WHERE tenant_id = $1", [dump(tenant_id)])
               end

               :cleared
             end)
  end

  defp activate_input(
         module_key,
         idempotency_key \\ UUID.generate(),
         causation_id \\ UUID.generate()
       ) do
    %{
      module_key: module_key,
      expected_version: 0,
      idempotency_key: idempotency_key,
      causation_id: causation_id
    }
  end

  defp runtime_options do
    [
      repositories: [pooled: [log: false, pool: DBConnection.ConnectionPool, pool_size: 4]],
      placements: [
        placement(@tenant_a, "pooled-module-lifecycle", :pooled),
        placement(@tenant_b, "pooled-module-lifecycle", :pooled)
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
        placement_ref: "pooled-module-lifecycle"
      )

    {:ok, context} =
      ExecutionContext.establish(
        actor,
        placement,
        correlation_id: correlation_id,
        purpose: @action_name,
        locale: "en"
      )

    context
  end

  defp dump(uuid), do: UUID.dump!(uuid)
end
