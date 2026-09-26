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

  alias Chimwemwe.Platform.ModuleLifecycle.{
    ActivateModuleResult,
    ReleaseManifest,
    TransitionResult
  }

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
  @deactivate_capability "platform.modules.deactivate"
  @mandatory_work_capability "platform.modules.mandatory_work.complete"
  @reactivate_capability "platform.modules.reactivate"
  @use_capability "platform.qualification.use"
  @base_module "platform.qualification.base"
  @dependent_module "platform.qualification.feature"
  @action_name "platform.module_lifecycle.activate"
  @deactivate_action "platform.module_lifecycle.deactivate"
  @mandatory_action "platform.module_lifecycle.complete_mandatory_work"
  @reactivate_action "platform.module_lifecycle.reactivate"

  @tables [
    "platform_governed_extension_definitions",
    "platform_authority_action_idempotency",
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

    assert {:error, :invalid_manifest} =
             ReleaseManifest.new([
               Map.put(declaration(@base_module), :compatible_from, [])
             ])

    assert {:ok, compatible_manifest} =
             ReleaseManifest.new([
               declaration(@base_module, [], "2.0.0", ["1.0.0", "2.0.0"])
             ])

    assert {:ok, %{compatible_from: ["1.0.0", "2.0.0"]}} =
             ReleaseManifest.fetch(compatible_manifest, @base_module)
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
                        "platform_module_activation_state_must_be_consistent"

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

  test "rejects active dependents and drains ordinary work without closing mandatory work",
       fixture do
    manifest = release_manifest()
    add_entitlement(fixture.runtime, context_admin_a(), @base_module)
    add_entitlement(fixture.runtime, context_admin_a(), @dependent_module)

    assert {:ok, %ActivateModuleResult{}} =
             ModuleLifecycle.activate(
               fixture.runtime,
               manifest,
               context_admin_a(),
               activate_input(@base_module)
             )

    assert {:ok, %ActivateModuleResult{}} =
             ModuleLifecycle.activate(
               fixture.runtime,
               manifest,
               context_admin_a(),
               activate_input(@dependent_module)
             )

    assert {:error, %ModuleLifecycleError{code: :active_dependents_present}} =
             ModuleLifecycle.deactivate(
               fixture.runtime,
               manifest,
               context_admin_a(),
               transition_input(@base_module, 1)
             )

    assert {:ok, %TransitionResult{state: :inactive, lock_version: 2}} =
             ModuleLifecycle.deactivate(
               fixture.runtime,
               manifest,
               context_admin_a(),
               transition_input(@dependent_module, 1)
             )

    base_activation_id = activation_id(fixture.runtime, context_admin_a(), @base_module)
    set_consumer_cursor(fixture.runtime, context_admin_a(), base_activation_id, 41)

    queued_id =
      add_work_item(fixture.runtime, context_admin_a(), base_activation_id, "ordinary", "queued")

    running_id =
      add_work_item(fixture.runtime, context_admin_a(), base_activation_id, "ordinary", "running")

    audit_id =
      add_work_item(fixture.runtime, context_admin_a(), base_activation_id, "audit", "queued")

    outbox_id =
      add_work_item(fixture.runtime, context_admin_a(), base_activation_id, "outbox", "running")

    retention_id =
      add_work_item(fixture.runtime, context_admin_a(), base_activation_id, "retention", "queued")

    deactivation_input = transition_input(@base_module, 1)

    assert {:ok,
            %TransitionResult{
              id: ^base_activation_id,
              transition: :deactivated,
              state: :inactive,
              lock_version: 2,
              parked_work_count: 2,
              replay_from_cursor: 41,
              projection_version: 1
            } = deactivated} =
             ModuleLifecycle.deactivate(
               fixture.runtime,
               manifest,
               context_admin_a(),
               deactivation_input
             )

    assert {:ok, ^deactivated} =
             ModuleLifecycle.deactivate(
               fixture.runtime,
               manifest,
               context_admin_a(UUID.generate()),
               deactivation_input
             )

    assert {:error, %ModuleLifecycleError{code: :idempotency_conflict}} =
             ModuleLifecycle.deactivate(
               fixture.runtime,
               manifest,
               context_admin_a(),
               %{deactivation_input | causation_id: UUID.generate()}
             )

    assert {:error, %ModuleLifecycleError{code: :module_inactive}} =
             ModuleLifecycle.authorize(
               fixture.runtime,
               manifest,
               context_admin_a(),
               @base_module,
               @use_capability
             )

    assert {:ok, drained_work} =
             read_work_items(fixture.runtime, context_admin_a(), base_activation_id)

    assert MapSet.new(drained_work) ==
             MapSet.new([
               [queued_id, "ordinary", "parked", 41],
               [running_id, "ordinary", "parked", 41],
               [audit_id, "audit", "queued", nil],
               [outbox_id, "outbox", "running", nil],
               [retention_id, "retention", "queued", nil]
             ])

    audit_input = mandatory_work_input(@base_module, audit_id, 2)

    assert {:ok, audit_result} =
             ModuleLifecycle.complete_mandatory_work(
               fixture.runtime,
               manifest,
               context_admin_a(),
               audit_input
             )

    assert %TransitionResult{
             transition: :mandatory_work_completed,
             state: :inactive,
             lock_version: 3,
             work_item_id: ^audit_id
           } = audit_result

    assert {:ok, ^audit_result} =
             ModuleLifecycle.complete_mandatory_work(
               fixture.runtime,
               manifest,
               context_admin_a(UUID.generate()),
               audit_input
             )

    assert {:ok, %TransitionResult{lock_version: 4, work_item_id: ^outbox_id}} =
             ModuleLifecycle.complete_mandatory_work(
               fixture.runtime,
               manifest,
               context_admin_a(),
               mandatory_work_input(@base_module, outbox_id, 3)
             )

    assert {:ok, %TransitionResult{lock_version: 5, work_item_id: ^retention_id}} =
             ModuleLifecycle.complete_mandatory_work(
               fixture.runtime,
               manifest,
               context_admin_a(),
               mandatory_work_input(@base_module, retention_id, 4)
             )

    assert {:error, %ModuleLifecycleError{code: :mandatory_work_not_available}} =
             ModuleLifecycle.complete_mandatory_work(
               fixture.runtime,
               manifest,
               context_admin_a(),
               mandatory_work_input(@base_module, queued_id, 5)
             )

    compatible_manifest =
      release_manifest([
        declaration(@base_module, [], "2.0.0", ["1.0.0", "2.0.0"]),
        declaration(@dependent_module, [@base_module], "2.0.0", ["1.0.0", "2.0.0"])
      ])

    reactivation_input = transition_input(@base_module, 5)

    assert {:ok,
            %TransitionResult{
              transition: :reactivated,
              module_version: "2.0.0",
              state: :active,
              lock_version: 6,
              requeued_work_count: 2,
              replay_from_cursor: 41,
              projection_version: 2
            } = reactivated} =
             ModuleLifecycle.reactivate(
               fixture.runtime,
               compatible_manifest,
               context_admin_a(),
               reactivation_input
             )

    assert {:ok, ^reactivated} =
             ModuleLifecycle.reactivate(
               fixture.runtime,
               compatible_manifest,
               context_admin_a(UUID.generate()),
               reactivation_input
             )

    grant_use_capability(fixture.runtime, context_admin_a(), fixture)

    assert :ok =
             ModuleLifecycle.authorize(
               fixture.runtime,
               compatible_manifest,
               context_admin_a(),
               @base_module,
               @use_capability
             )

    assert {:ok, [["2.0.0", "active", 6, 41, nil, 41, 2, true, false, "retained"]]} =
             read_lifecycle_state(fixture.runtime, context_admin_a(), @base_module)

    assert {:ok, reactivated_work} =
             read_work_items(fixture.runtime, context_admin_a(), base_activation_id)

    assert MapSet.new(reactivated_work) ==
             MapSet.new([
               [queued_id, "ordinary", "queued", 41],
               [running_id, "ordinary", "queued", 41],
               [audit_id, "audit", "completed", nil],
               [outbox_id, "outbox", "completed", nil],
               [retention_id, "retention", "completed", nil]
             ])

    assert {:ok, [[5, 5, 5]]} =
             transition_fact_counts(fixture.runtime, context_admin_a(), base_activation_id)
  end

  test "incompatible and failed reconciliation leave the module inactive and retryable",
       fixture do
    manifest = release_manifest([declaration(@base_module)])
    add_entitlement(fixture.runtime, context_admin_a(), @base_module)

    assert {:ok, %ActivateModuleResult{id: activation_id}} =
             ModuleLifecycle.activate(
               fixture.runtime,
               manifest,
               context_admin_a(),
               activate_input(@base_module)
             )

    work_item_id =
      add_work_item(fixture.runtime, context_admin_a(), activation_id, "ordinary", "queued")

    set_consumer_cursor(fixture.runtime, context_admin_a(), activation_id, 17)

    assert {:ok, %TransitionResult{lock_version: 2}} =
             ModuleLifecycle.deactivate(
               fixture.runtime,
               manifest,
               context_admin_a(),
               transition_input(@base_module, 1)
             )

    incompatible_manifest =
      release_manifest([declaration(@base_module, [], "2.0.0", ["2.0.0"])])

    assert {:error, %ModuleLifecycleError{code: :module_version_incompatible}} =
             ModuleLifecycle.reactivate(
               fixture.runtime,
               incompatible_manifest,
               context_admin_a(),
               transition_input(@base_module, 2)
             )

    compatible_manifest =
      release_manifest([declaration(@base_module, [], "2.0.0", ["1.0.0"])])

    input = transition_input(@base_module, 2)
    install_completion_failure(fixture.runtime, @reactivate_action)
    on_exit(fn -> remove_completion_failure(fixture.runtime) end)

    assert {:error, %ModuleLifecycleError{code: :retryable_dependency}} =
             ModuleLifecycle.reactivate(
               fixture.runtime,
               compatible_manifest,
               context_admin_a(),
               input
             )

    assert {:ok, [["1.0.0", "inactive", 2, 17, 17, 0, 1, false, true, "retained"]]} =
             read_lifecycle_state(fixture.runtime, context_admin_a(), @base_module)

    assert {:ok, [[^work_item_id, "ordinary", "parked", 17]]} =
             read_work_items(fixture.runtime, context_admin_a(), activation_id)

    remove_completion_failure(fixture.runtime)

    assert {:ok, %TransitionResult{state: :active, lock_version: 3}} =
             ModuleLifecycle.reactivate(
               fixture.runtime,
               compatible_manifest,
               context_admin_a(),
               input
             )
  end

  test "an ordinary transaction that owns the lifecycle lock finishes before deactivation",
       fixture do
    manifest = release_manifest([declaration(@base_module)])
    add_entitlement(fixture.runtime, context_admin_a(), @base_module)
    grant_use_capability(fixture.runtime, context_admin_a(), fixture)

    assert {:ok, %ActivateModuleResult{id: activation_id}} =
             ModuleLifecycle.activate(
               fixture.runtime,
               manifest,
               context_admin_a(),
               activate_input(@base_module)
             )

    work_item_id =
      add_work_item(fixture.runtime, context_admin_a(), activation_id, "ordinary", "running")

    parent = self()

    ordinary_task =
      Task.async(fn ->
        Persistence.with_writer(fixture.runtime, context_admin_a(), fn ->
          Repo.transaction(fn ->
            assert :ok =
                     ModuleLifecycle.authorize_current_transaction(
                       manifest,
                       context_admin_a(),
                       @base_module,
                       @use_capability
                     )

            send(parent, :ordinary_locked)

            receive do
              :finish_ordinary -> :ok
            after
              2_000 -> flunk("ordinary transaction was not released")
            end

            Repo.query!(
              """
              UPDATE platform_module_work_items
              SET status = 'completed', updated_at = NOW()
              WHERE id = $1 AND tenant_id = $2 AND activation_id = $3
              """,
              Enum.map([work_item_id, @tenant_a, activation_id], &dump/1)
            )

            :ordinary_committed
          end)
        end)
      end)

    assert_receive :ordinary_locked, 2_000

    deactivate_task =
      Task.async(fn ->
        ModuleLifecycle.deactivate(
          fixture.runtime,
          manifest,
          context_admin_a(),
          transition_input(@base_module, 1)
        )
      end)

    refute Task.yield(deactivate_task, 100)
    send(ordinary_task.pid, :finish_ordinary)

    assert {:ok, {:ok, :ordinary_committed}} = Task.await(ordinary_task, 2_000)

    assert {:ok, %TransitionResult{state: :inactive, parked_work_count: 0}} =
             Task.await(deactivate_task, 2_000)

    assert {:ok, [[^work_item_id, "ordinary", "completed", nil]]} =
             read_work_items(fixture.runtime, context_admin_a(), activation_id)
  end

  test "deactivation that owns the lifecycle lock closes authority before ordinary work",
       fixture do
    manifest = release_manifest([declaration(@base_module)])
    add_entitlement(fixture.runtime, context_admin_a(), @base_module)
    grant_use_capability(fixture.runtime, context_admin_a(), fixture)

    assert {:ok, %ActivateModuleResult{id: activation_id}} =
             ModuleLifecycle.activate(
               fixture.runtime,
               manifest,
               context_admin_a(),
               activate_input(@base_module)
             )

    work_item_id =
      add_work_item(fixture.runtime, context_admin_a(), activation_id, "ordinary", "running")

    blocker_key = 4_201_041
    install_deactivation_blocker(fixture.runtime, blocker_key)
    parent = self()

    blocker =
      Task.async(fn ->
        Persistence.with_writer(fixture.runtime, context_admin_a(), fn ->
          Repo.checkout(fn ->
            Repo.query!("SELECT pg_advisory_lock($1)", [blocker_key])
            send(parent, :deactivation_blocker_held)

            receive do
              :release_deactivation -> :ok
            after
              3_000 -> flunk("deactivation blocker was not released")
            end

            Repo.query!("SELECT pg_advisory_unlock($1)", [blocker_key])
            :released
          end)
        end)
      end)

    on_exit(fn ->
      send(blocker.pid, :release_deactivation)
      remove_deactivation_blocker(fixture.runtime)
    end)

    assert_receive :deactivation_blocker_held, 2_000

    deactivate_task =
      Task.async(fn ->
        ModuleLifecycle.deactivate(
          fixture.runtime,
          manifest,
          context_admin_a(),
          transition_input(@base_module, 1)
        )
      end)

    assert :ok = await_advisory_waiter(fixture.runtime, blocker_key)

    ordinary_task =
      Task.async(fn ->
        Persistence.with_writer(fixture.runtime, context_admin_a(), fn ->
          Repo.transaction(fn ->
            ModuleLifecycle.authorize_current_transaction(
              manifest,
              context_admin_a(),
              @base_module,
              @use_capability
            )
          end)
        end)
      end)

    refute Task.yield(ordinary_task, 100)
    send(blocker.pid, :release_deactivation)

    assert {:ok,
            %TransitionResult{
              state: :inactive,
              lock_version: 2,
              parked_work_count: 1
            }} = Task.await(deactivate_task, 2_000)

    assert {:ok, {:ok, {:error, %ModuleLifecycleError{code: :module_inactive}}}} =
             Task.await(ordinary_task, 2_000)

    assert {:ok, :released} = Task.await(blocker, 2_000)

    assert {:ok, [[^work_item_id, "ordinary", "parked", 0]]} =
             read_work_items(fixture.runtime, context_admin_a(), activation_id)
  end

  test "transition actions reject missing authority, forged input, and cross-tenant work",
       fixture do
    manifest = release_manifest([declaration(@base_module)])
    add_entitlement(fixture.runtime, context_admin_a(), @base_module)
    add_entitlement(fixture.runtime, context_admin_b(), @base_module)

    assert {:ok, %ActivateModuleResult{id: activation_a}} =
             ModuleLifecycle.activate(
               fixture.runtime,
               manifest,
               context_admin_a(),
               activate_input(@base_module)
             )

    assert {:ok, %ActivateModuleResult{id: activation_b}} =
             ModuleLifecycle.activate(
               fixture.runtime,
               manifest,
               context_admin_b(),
               activate_input(@base_module)
             )

    work_item_a =
      add_work_item(fixture.runtime, context_admin_a(), activation_a, "retention", "queued")

    assert {:error, %ModuleLifecycleError{code: :forbidden}} =
             ModuleLifecycle.deactivate(
               fixture.runtime,
               manifest,
               context_denied_a(),
               transition_input(@base_module, 1)
             )

    assert {:error, %ModuleLifecycleError{code: :forbidden}} =
             ModuleLifecycle.complete_mandatory_work(
               fixture.runtime,
               manifest,
               context_denied_a(),
               mandatory_work_input(@base_module, work_item_a, 1)
             )

    assert {:error, %ModuleLifecycleError{code: :forbidden}} =
             ModuleLifecycle.reactivate(
               fixture.runtime,
               manifest,
               context_denied_a(),
               transition_input(@base_module, 1)
             )

    assert {:error, %ModuleLifecycleError{code: :invalid_input}} =
             ModuleLifecycle.deactivate(
               fixture.runtime,
               manifest,
               context_admin_a(),
               Map.put(transition_input(@base_module, 1), :tenant_id, @tenant_b)
             )

    assert {:error, %ContextError{code: :missing_trusted_context}} =
             ModuleLifecycle.reactivate(
               fixture.runtime,
               manifest,
               %{tenant_id: @tenant_a},
               transition_input(@base_module, 1)
             )

    assert {:error, %ModuleLifecycleError{code: :mandatory_work_not_available}} =
             ModuleLifecycle.complete_mandatory_work(
               fixture.runtime,
               manifest,
               context_admin_b(),
               mandatory_work_input(@base_module, work_item_a, 1)
             )

    assert {:error, %ModuleLifecycleError{code: :retryable_dependency}} =
             ModuleLifecycle.authorize_current_transaction(
               manifest,
               context_admin_a(),
               @base_module,
               @use_capability
             )

    assert {:ok, :checked} =
             Persistence.with_writer(fixture.runtime, context_admin_a(), fn ->
               cross_tenant_error =
                 assert_raise PostgrexError, fn ->
                   insert_work_item_directly(@tenant_a, activation_b, "ordinary", "queued", nil)
                 end

               assert cross_tenant_error.postgres.constraint ==
                        "platform_module_work_items_activation_tenant_fkey"

               parked_mandatory_error =
                 assert_raise PostgrexError, fn ->
                   insert_work_item_directly(
                     @tenant_a,
                     activation_a,
                     "retention",
                     "parked",
                     nil
                   )
                 end

               assert parked_mandatory_error.postgres.constraint ==
                        "platform_module_work_item_parking_must_be_ordinary"

               cursor_error =
                 assert_raise PostgrexError, fn ->
                   insert_work_item_directly(@tenant_a, activation_a, "ordinary", "queued", -1)
                 end

               assert cursor_error.postgres.constraint ==
                        "platform_module_work_item_cursor_must_be_nonnegative"

               retained_state_error =
                 assert_raise PostgrexError, fn ->
                   Repo.query!(
                     """
                     UPDATE platform_module_activations
                     SET retained_data_state = 'released'
                     WHERE id = $1 AND tenant_id = $2
                     """,
                     [dump(activation_a), dump(@tenant_a)]
                   )
                 end

               assert retained_state_error.postgres.constraint ==
                        "platform_module_activation_retained_data_must_remain_owned"

               :checked
             end)

    assert {:ok, [["1.0.0", "active", 1, 0, nil, 0, 1, true, false, "retained"]]} =
             read_lifecycle_state(fixture.runtime, context_admin_a(), @base_module)
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

  defp declaration(key, dependencies \\ [], version \\ "1.0.0", compatible_from \\ nil) do
    declaration = %{
      key: key,
      version: version,
      owner: "Platform engineering",
      dependencies: dependencies
    }

    if compatible_from,
      do: Map.put(declaration, :compatible_from, compatible_from),
      else: declaration
  end

  defp seed_authority(runtime) do
    ids = %{
      admin_role_a: UUID.generate(),
      admin_role_b: UUID.generate(),
      activate_capability_a: UUID.generate(),
      activate_capability_b: UUID.generate(),
      deactivate_capability_a: UUID.generate(),
      deactivate_capability_b: UUID.generate(),
      mandatory_work_capability_a: UUID.generate(),
      mandatory_work_capability_b: UUID.generate(),
      reactivate_capability_a: UUID.generate(),
      reactivate_capability_b: UUID.generate(),
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
               insert_capability(ids.deactivate_capability_a, @tenant_a, @deactivate_capability)

               insert_capability(
                 ids.mandatory_work_capability_a,
                 @tenant_a,
                 @mandatory_work_capability
               )

               insert_capability(ids.reactivate_capability_a, @tenant_a, @reactivate_capability)
               insert_capability(ids.use_capability_a, @tenant_a, @use_capability)
               insert_assignment(@tenant_a, ids.admin_membership_a, ids.admin_role_a)
               insert_assignment(@tenant_a, ids.admin_peer_membership_a, ids.admin_role_a)
               insert_grant(@tenant_a, ids.admin_role_a, ids.activate_capability_a)
               insert_grant(@tenant_a, ids.admin_role_a, ids.deactivate_capability_a)
               insert_grant(@tenant_a, ids.admin_role_a, ids.mandatory_work_capability_a)
               insert_grant(@tenant_a, ids.admin_role_a, ids.reactivate_capability_a)
               :seeded
             end)

    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context_admin_b(), fn ->
               insert_membership(ids.admin_membership_b, @tenant_b, @admin_b)
               insert_role(ids.admin_role_b, @tenant_b, "Module lifecycle manager")
               insert_capability(ids.activate_capability_b, @tenant_b, @activate_capability)
               insert_capability(ids.deactivate_capability_b, @tenant_b, @deactivate_capability)

               insert_capability(
                 ids.mandatory_work_capability_b,
                 @tenant_b,
                 @mandatory_work_capability
               )

               insert_capability(ids.reactivate_capability_b, @tenant_b, @reactivate_capability)
               insert_assignment(@tenant_b, ids.admin_membership_b, ids.admin_role_b)
               insert_grant(@tenant_b, ids.admin_role_b, ids.activate_capability_b)
               insert_grant(@tenant_b, ids.admin_role_b, ids.deactivate_capability_b)
               insert_grant(@tenant_b, ids.admin_role_b, ids.mandatory_work_capability_b)
               insert_grant(@tenant_b, ids.admin_role_b, ids.reactivate_capability_b)
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

  defp activation_id(runtime, context, module_key) do
    assert {:ok, [[activation_id]]} =
             Persistence.with_writer(runtime, context, fn ->
               Repo.query!(
                 """
                 SELECT activation.id::text
                 FROM platform_module_activations AS activation
                 JOIN platform_module_entitlements AS entitlement
                   ON entitlement.tenant_id = activation.tenant_id
                  AND entitlement.id = activation.entitlement_id
                 WHERE activation.tenant_id = $1 AND entitlement.module_key = $2
                 """,
                 [dump(TrustedActor.tenant_id(context.actor)), module_key]
               ).rows
             end)

    activation_id
  end

  defp add_work_item(runtime, context, activation_id, work_kind, status) do
    work_item_id = UUID.generate()

    assert {:ok, :inserted} =
             Persistence.with_writer(runtime, context, fn ->
               Repo.query!(
                 """
                 INSERT INTO platform_module_work_items (
                   id, tenant_id, activation_id, work_kind, status, inserted_at, updated_at
                 )
                 VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
                 """,
                 [
                   dump(work_item_id),
                   dump(TrustedActor.tenant_id(context.actor)),
                   dump(activation_id),
                   work_kind,
                   status
                 ]
               )

               :inserted
             end)

    work_item_id
  end

  defp insert_work_item_directly(tenant_id, activation_id, work_kind, status, replay_cursor) do
    Repo.query!(
      """
      INSERT INTO platform_module_work_items (
        id, tenant_id, activation_id, work_kind, status, replay_cursor, inserted_at, updated_at
      )
      VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
      """,
      [
        dump(UUID.generate()),
        dump(tenant_id),
        dump(activation_id),
        work_kind,
        status,
        replay_cursor
      ]
    )
  end

  defp set_consumer_cursor(runtime, context, activation_id, cursor) do
    assert {:ok, :updated} =
             Persistence.with_writer(runtime, context, fn ->
               Repo.query!(
                 """
                 UPDATE platform_module_activations
                 SET consumer_cursor = $3, updated_at = NOW()
                 WHERE id = $1 AND tenant_id = $2
                 """,
                 [
                   dump(activation_id),
                   dump(TrustedActor.tenant_id(context.actor)),
                   cursor
                 ]
               )

               :updated
             end)
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

  defp read_lifecycle_state(runtime, context, module_key) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT activation.module_version,
               activation.state,
               activation.lock_version,
               activation.consumer_cursor,
               activation.replay_from_cursor,
               activation.last_reconciled_cursor,
               activation.projection_version,
               activation.projection_ready,
               activation.reconciliation_required,
               activation.retained_data_state
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

  defp read_work_items(runtime, context, activation_id) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT id::text, work_kind, status, replay_cursor
        FROM platform_module_work_items
        WHERE tenant_id = $1 AND activation_id = $2
        ORDER BY inserted_at, id
        """,
        [dump(TrustedActor.tenant_id(context.actor)), dump(activation_id)]
      ).rows
    end)
  end

  defp transition_fact_counts(runtime, context, activation_id) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT
          (SELECT count(*) FROM platform_authority_audit_events
           WHERE tenant_id = $1 AND aggregate_id = $2
             AND action_name IN ($3, $4, $5)),
          (SELECT count(*) FROM platform_outbox_events
           WHERE tenant_id = $1 AND aggregate_id = $2
             AND event_type IN (
               'platform.module.deactivated',
               'platform.module.mandatory_work_completed',
               'platform.module.reactivated'
             )),
          (SELECT count(*) FROM platform_authority_action_idempotency
           WHERE tenant_id = $1 AND aggregate_id = $2
             AND action_name IN ($3, $4, $5))
        """,
        [
          dump(TrustedActor.tenant_id(context.actor)),
          dump(activation_id),
          @deactivate_action,
          @mandatory_action,
          @reactivate_action
        ]
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

  defp install_completion_failure(runtime, action_name \\ @action_name) do
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
                    AND NEW.action_name = '#{action_name}' THEN
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

  defp install_deactivation_blocker(runtime, blocker_key) do
    assert {:ok, :installed} =
             Persistence.with_writer(runtime, context_admin_a(), fn ->
               Repo.query!(
                 "DROP TRIGGER IF EXISTS test_block_module_deactivation ON platform_module_activations"
               )

               Repo.query!("DROP FUNCTION IF EXISTS test_block_module_deactivation()")

               Repo.query!("""
               CREATE FUNCTION test_block_module_deactivation()
               RETURNS trigger
               LANGUAGE plpgsql
               AS $$
               BEGIN
                 IF OLD.state = 'active' AND NEW.state = 'inactive' THEN
                   PERFORM pg_advisory_xact_lock(#{blocker_key});
                 END IF;

                 RETURN NEW;
               END;
               $$;
               """)

               Repo.query!("""
               CREATE TRIGGER test_block_module_deactivation
               BEFORE UPDATE OF state
               ON platform_module_activations
               FOR EACH ROW
               EXECUTE FUNCTION test_block_module_deactivation();
               """)

               :installed
             end)
  end

  defp remove_deactivation_blocker(runtime) do
    Persistence.with_writer(runtime, context_admin_a(), fn ->
      Repo.query!(
        "DROP TRIGGER IF EXISTS test_block_module_deactivation ON platform_module_activations"
      )

      Repo.query!("DROP FUNCTION IF EXISTS test_block_module_deactivation()")
      :removed
    end)
  end

  defp await_advisory_waiter(runtime, blocker_key, attempts \\ 100)

  defp await_advisory_waiter(_runtime, _blocker_key, 0),
    do: flunk("deactivation did not reach the database blocker")

  defp await_advisory_waiter(runtime, blocker_key, attempts) do
    case Persistence.with_writer(runtime, context_admin_a(), fn ->
           Repo.query!(
             """
             SELECT count(*)
             FROM pg_locks
             WHERE locktype = 'advisory'
               AND classid = 0
               AND objid = $1
               AND objsubid = 1
               AND granted = false
             """,
             [blocker_key]
           ).rows
         end) do
      {:ok, [[count]]} when count > 0 ->
        :ok

      {:ok, [[0]]} ->
        Process.sleep(20)
        await_advisory_waiter(runtime, blocker_key, attempts - 1)
    end
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

  defp transition_input(
         module_key,
         expected_version,
         idempotency_key \\ UUID.generate(),
         causation_id \\ UUID.generate()
       ) do
    %{
      module_key: module_key,
      expected_version: expected_version,
      idempotency_key: idempotency_key,
      causation_id: causation_id
    }
  end

  defp mandatory_work_input(
         module_key,
         work_item_id,
         expected_version,
         idempotency_key \\ UUID.generate(),
         causation_id \\ UUID.generate()
       ) do
    transition_input(module_key, expected_version, idempotency_key, causation_id)
    |> Map.put(:work_item_id, work_item_id)
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
