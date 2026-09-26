defmodule Chimwemwe.Platform.OutboxTest do
  use ExUnit.Case, async: false

  alias Chimwemwe.Platform.{
    ContextError,
    ExecutionContext,
    Outbox,
    OutboxError,
    Persistence,
    PersistenceError,
    PersistenceRuntime,
    TrustedActor,
    TrustedPlacement
  }

  alias Chimwemwe.Platform.Outbox.{ConsumerRegistry, DeliveryResult, Envelope, Status}
  alias Chimwemwe.Repo
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  @tenant_a "11111111-1111-4111-8111-111111111111"
  @tenant_b "22222222-2222-4222-8222-222222222222"
  @dispatcher_a "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  @dispatcher_b "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
  @dispatch_only_a "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
  @observe_only_a "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee"
  @dispatch_capability "platform.outbox.dispatch"
  @observe_capability "platform.outbox.observe"
  @consumer_key "platform.operations.test_sink"
  @event_type "platform.authority.role.renamed"

  @tables [
    "platform_outbox_deliveries",
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
    seed_authority(runtime)
    {:ok, runtime: runtime}
  end

  test "consumer declarations are immutable, exact, and bounded" do
    assert {:ok, registry} = ConsumerRegistry.new([consumer_declaration()])
    assert {:ok, declaration} = ConsumerRegistry.fetch(registry, @consumer_key)
    assert declaration.batch_size == 2
    assert declaration.lease_ms == 60_000
    assert ConsumerRegistry.event_pairs(declaration) == {[@event_type], [1]}

    assert {:error, :invalid_registry} =
             ConsumerRegistry.new([consumer_declaration(), consumer_declaration()])

    assert {:error, :invalid_registry} =
             ConsumerRegistry.new([
               consumer_declaration(%{batch_size: 101})
             ])

    assert {:error, :invalid_registry} =
             ConsumerRegistry.new([
               consumer_declaration(%{
                 events: [%{type: @event_type, schema_versions: [1, 1]}]
               })
             ])
  end

  test "claims only the current tenant, route, subscription, schema, and bounded batch", %{
    runtime: runtime
  } do
    first = insert_event(runtime, context_dispatcher_a())
    second = insert_event(runtime, context_dispatcher_a())
    third = insert_event(runtime, context_dispatcher_a())
    _other_tenant = insert_event(runtime, context_dispatcher_b())
    _stale_route = insert_event(runtime, context_dispatcher_a(), routing_version: 6)
    _wrong_schema = insert_event(runtime, context_dispatcher_a(), schema_version: 2)

    _wrong_type =
      insert_event(runtime, context_dispatcher_a(), event_type: "platform.other.event")

    assert {:ok, [%Envelope{}, %Envelope{}] = envelopes} =
             Outbox.claim(runtime, registry(), context_dispatcher_a(), @consumer_key)

    assert Enum.map(envelopes, & &1.event_id) == [first, second]
    assert Enum.all?(envelopes, &(&1.attempt_count == 1 and &1.classification == :internal))
    assert Enum.all?(envelopes, &(&1.routing_version == 7 and &1.schema_version == 1))
    assert Enum.all?(envelopes, &(MapSet.new(Map.keys(&1)) |> MapSet.member?(:payload)))
    assert Enum.all?(envelopes, &(&1.tenant_id == @tenant_a))
    assert Enum.all?(envelopes, &(&1.actor_id == @dispatcher_a))

    assert {:ok, [%Envelope{event_id: ^third}]} =
             Outbox.claim(runtime, registry(), context_dispatcher_a(), @consumer_key)

    assert {:ok, []} =
             Outbox.claim(runtime, registry(), context_dispatcher_a(), @consumer_key)

    assert {:ok, %Status{} = status} =
             Outbox.status(runtime, registry(), context_dispatcher_a(), @consumer_key)

    assert status.leased == 3
    assert status.stale_route == 1
    assert status.unclaimed == 0
    refute Map.has_key?(status, :consumer_key)
    refute Map.has_key?(status, :tenant_id)
    refute Map.has_key?(status, :event_id)
  end

  test "separates dispatch and observe authority and fails before event lookup", %{
    runtime: runtime
  } do
    event_id = insert_event(runtime, context_dispatcher_a())

    assert {:error, %ContextError{code: :missing_trusted_context}} =
             Outbox.claim(runtime, registry(), nil, @consumer_key)

    assert {:error, %ContextError{code: :missing_trusted_context}} =
             Outbox.status(runtime, registry(), %{tenant_id: @tenant_a}, @consumer_key)

    assert {:error, %OutboxError{code: :forbidden}} =
             Outbox.status(runtime, registry(), context_dispatch_only_a(), @consumer_key)

    assert {:error, %OutboxError{code: :forbidden}} =
             Outbox.claim(runtime, registry(), context_observe_only_a(), @consumer_key)

    assert {:ok, %Status{unclaimed: 1}} =
             Outbox.status(runtime, registry(), context_observe_only_a(), @consumer_key)

    assert {:error, %OutboxError{code: :consumer_not_available}} =
             Outbox.claim(
               runtime,
               registry(),
               context_dispatcher_a(),
               "platform.missing.consumer"
             )

    assert {:error, %OutboxError{code: :invalid_input}} =
             Outbox.acknowledge(
               runtime,
               registry(),
               context_dispatcher_a(),
               @consumer_key,
               "request-id",
               UUID.generate()
             )

    assert {:ok, []} = Outbox.claim(runtime, registry(), context_dispatcher_b(), @consumer_key)

    assert {:error, %OutboxError{code: :not_found}} =
             Outbox.acknowledge(
               runtime,
               registry(),
               context_dispatcher_b(),
               @consumer_key,
               event_id,
               UUID.generate()
             )
  end

  test "competing claims produce one lease and an expired lease is reclaimed", %{
    runtime: runtime
  } do
    event_id = insert_event(runtime, context_dispatcher_a())
    registry = registry(%{batch_size: 1})

    tasks =
      for _index <- 1..2 do
        Task.async(fn ->
          Outbox.claim(runtime, registry, context_dispatcher_a(), @consumer_key)
        end)
      end

    results = Enum.map(tasks, &Task.await(&1, 5_000))

    assert 1 == Enum.count(results, &match?({:ok, [%Envelope{}]}, &1))
    assert 1 == Enum.count(results, &match?({:ok, []}, &1))

    {:ok, [%Envelope{lease_token: first_token}]} =
      Enum.find(results, &match?({:ok, [%Envelope{}]}, &1))

    expire_lease(runtime, context_dispatcher_a(), event_id)

    assert {:error, %OutboxError{code: :conflict}} =
             Outbox.acknowledge(
               runtime,
               registry,
               context_dispatcher_a(),
               @consumer_key,
               event_id,
               first_token
             )

    assert {:error, %OutboxError{code: :conflict}} =
             Outbox.fail(
               runtime,
               registry,
               context_dispatcher_a(),
               @consumer_key,
               event_id,
               first_token,
               :retryable_dependency
             )

    assert {:ok,
            [
              %Envelope{
                event_id: ^event_id,
                attempt_count: 2,
                lease_token: second_token
              }
            ]} = Outbox.claim(runtime, registry, context_dispatcher_a(), @consumer_key)

    refute second_token == first_token

    assert {:error, %OutboxError{code: :conflict}} =
             Outbox.acknowledge(
               runtime,
               registry,
               context_dispatcher_a(),
               @consumer_key,
               event_id,
               first_token
             )
  end

  test "acknowledgement is exact and idempotent for the same completed lease", %{
    runtime: runtime
  } do
    event_id = insert_event(runtime, context_dispatcher_a())
    assert {:ok, [%Envelope{lease_token: token}]} = claim(runtime)

    assert {:ok, %DeliveryResult{status: :completed, lock_version: 2} = completed} =
             acknowledge(runtime, event_id, token)

    assert {:ok, ^completed} = acknowledge(runtime, event_id, token)

    assert {:error, %OutboxError{code: :conflict}} =
             acknowledge(runtime, event_id, UUID.generate())

    assert {:ok, %Status{completed: 1, leased: 0}} =
             Outbox.status(runtime, registry(), context_dispatcher_a(), @consumer_key)
  end

  test "failure retries after the declared delay and dead-letters at the attempt limit", %{
    runtime: runtime
  } do
    event_id = insert_event(runtime, context_dispatcher_a())
    registry = registry(%{max_attempts: 2, retry_ms: 60_000})
    assert {:ok, [%Envelope{lease_token: first_token}]} = claim(runtime, registry)

    assert {:ok, %DeliveryResult{status: :available, attempt_count: 1} = failed} =
             Outbox.fail(
               runtime,
               registry,
               context_dispatcher_a(),
               @consumer_key,
               event_id,
               first_token,
               :retryable_dependency
             )

    assert {:ok, ^failed} =
             Outbox.fail(
               runtime,
               registry,
               context_dispatcher_a(),
               @consumer_key,
               event_id,
               first_token,
               :retryable_dependency
             )

    assert {:error, %OutboxError{code: :conflict}} =
             Outbox.fail(
               runtime,
               registry,
               context_dispatcher_a(),
               @consumer_key,
               event_id,
               first_token,
               :consumer_rejected
             )

    assert {:ok, []} = claim(runtime, registry)
    make_available(runtime, context_dispatcher_a(), event_id)

    assert {:ok, [%Envelope{attempt_count: 2, lease_token: second_token}]} =
             claim(runtime, registry)

    assert {:ok, %DeliveryResult{status: :dead_letter, attempt_count: 2}} =
             Outbox.fail(
               runtime,
               registry,
               context_dispatcher_a(),
               @consumer_key,
               event_id,
               second_token,
               :consumer_rejected
             )

    assert {:ok, []} = claim(runtime, registry)

    assert {:ok, %Status{dead_letter: 1, available: 0}} =
             Outbox.status(runtime, registry, context_dispatcher_a(), @consumer_key)
  end

  test "unavailable persistence and alternate tenant/state writes fail closed", %{
    runtime: runtime
  } do
    event_id = insert_event(runtime, context_dispatcher_a())

    assert {:error, %PersistenceError{code: :retryable_dependency}} =
             Outbox.claim(self(), registry(), context_dispatcher_a(), @consumer_key)

    assert {:error, %PostgrexError{postgres: %{code: :foreign_key_violation}}} =
             insert_delivery_directly(runtime, context_dispatcher_b(), event_id)

    own_event_id = insert_event(runtime, context_dispatcher_b())

    assert {:error, %PostgrexError{postgres: %{code: :check_violation}}} =
             insert_delivery_directly(runtime, context_dispatcher_b(), own_event_id,
               status: "completed",
               lease_token: UUID.generate(),
               completed_at: nil
             )
  end

  defp claim(runtime, registry \\ registry()) do
    Outbox.claim(runtime, registry, context_dispatcher_a(), @consumer_key)
  end

  defp acknowledge(runtime, event_id, token) do
    Outbox.acknowledge(
      runtime,
      registry(),
      context_dispatcher_a(),
      @consumer_key,
      event_id,
      token
    )
  end

  defp registry(overrides \\ %{}) do
    assert {:ok, registry} = ConsumerRegistry.new([consumer_declaration(overrides)])
    registry
  end

  defp consumer_declaration(overrides \\ %{}) do
    Map.merge(
      %{
        key: @consumer_key,
        events: [%{type: @event_type, schema_versions: [1]}],
        batch_size: 2,
        lease_ms: 60_000,
        max_attempts: 3,
        retry_ms: 60_000
      },
      overrides
    )
  end

  defp seed_authority(runtime) do
    seed_tenant(runtime, context_dispatcher_a(), @tenant_a, @dispatcher_a, [
      @dispatch_capability,
      @observe_capability
    ])

    seed_actor(runtime, context_dispatcher_a(), @tenant_a, @dispatch_only_a, [
      @dispatch_capability
    ])

    seed_actor(runtime, context_dispatcher_a(), @tenant_a, @observe_only_a, [
      @observe_capability
    ])

    seed_tenant(runtime, context_dispatcher_b(), @tenant_b, @dispatcher_b, [
      @dispatch_capability,
      @observe_capability
    ])
  end

  defp seed_tenant(runtime, context, tenant_id, actor_id, capabilities) do
    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context, fn ->
               role_id = UUID.generate()
               membership_id = insert_membership(tenant_id, actor_id)
               insert_role(role_id, tenant_id)
               insert_assignment(tenant_id, membership_id, role_id)

               Enum.each(capabilities, fn capability ->
                 capability_id = insert_capability(tenant_id, capability)
                 insert_grant(tenant_id, role_id, capability_id)
               end)

               :seeded
             end)
  end

  defp seed_actor(runtime, context, tenant_id, actor_id, capabilities) do
    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context, fn ->
               role_id = UUID.generate()
               membership_id = insert_membership(tenant_id, actor_id)
               insert_role(role_id, tenant_id)
               insert_assignment(tenant_id, membership_id, role_id)

               Enum.each(capabilities, fn capability ->
                 %{rows: [[capability_id]]} =
                   Repo.query!(
                     "SELECT id FROM platform_capabilities WHERE tenant_id = $1 AND key = $2",
                     [dump(tenant_id), capability]
                   )

                 insert_grant(tenant_id, role_id, UUID.load!(capability_id))
               end)

               :seeded
             end)
  end

  defp insert_membership(tenant_id, actor_id) do
    id = UUID.generate()

    Repo.query!(
      """
      INSERT INTO platform_tenant_memberships (id, tenant_id, actor_id, inserted_at, updated_at)
      VALUES ($1, $2, $3, NOW(), NOW())
      """,
      Enum.map([id, tenant_id, actor_id], &dump/1)
    )

    id
  end

  defp insert_role(id, tenant_id) do
    Repo.query!(
      """
      INSERT INTO platform_roles (id, tenant_id, name, lock_version, inserted_at, updated_at)
      VALUES ($1, $2, $3, 1, NOW(), NOW())
      """,
      [dump(id), dump(tenant_id), "Outbox operator #{id}"]
    )
  end

  defp insert_capability(tenant_id, key) do
    id = UUID.generate()

    Repo.query!(
      """
      INSERT INTO platform_capabilities (id, tenant_id, key, inserted_at, updated_at)
      VALUES ($1, $2, $3, NOW(), NOW())
      """,
      [dump(id), dump(tenant_id), key]
    )

    id
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

  defp insert_event(runtime, context, overrides \\ []) do
    event_id = UUID.generate()
    audit_id = UUID.generate()
    tenant_id = TrustedActor.tenant_id(context.actor)

    assert {:ok, :inserted} =
             Persistence.with_writer(runtime, context, fn ->
               Repo.query!(
                 """
                 INSERT INTO platform_authority_audit_events (
                   id, tenant_id, actor_id, action_name, aggregate_type, aggregate_id,
                   idempotency_key, correlation_id, causation_id, before_version,
                   after_version, change_summary, occurred_at, inserted_at
                 )
                 VALUES (
                   $1, $2, $3, 'platform.test.changed', 'platform.test', $4,
                   $5, $6, $7, 1, 2, '{}'::jsonb, NOW(), NOW()
                 )
                 """,
                 Enum.map(
                   [
                     audit_id,
                     tenant_id,
                     TrustedActor.actor_id(context.actor),
                     UUID.generate(),
                     UUID.generate(),
                     context.correlation_id,
                     UUID.generate()
                   ],
                   &dump/1
                 )
               )

               Repo.query!(
                 """
                 INSERT INTO platform_outbox_events (
                   id, tenant_id, actor_id, aggregate_type, aggregate_id, event_type,
                   schema_version, routing_version, correlation_id, causation_id,
                   audit_reference, classification, payload, occurred_at, inserted_at
                 )
                 VALUES (
                   $1, $2, $3, 'platform.test', $4, $5, $6, $7, $8, $9,
                   $10, 'internal', $11::jsonb, NOW(), NOW()
                 )
                 """,
                 [
                   dump(event_id),
                   dump(tenant_id),
                   dump(TrustedActor.actor_id(context.actor)),
                   dump(UUID.generate()),
                   Keyword.get(overrides, :event_type, @event_type),
                   Keyword.get(overrides, :schema_version, 1),
                   Keyword.get(overrides, :routing_version, 7),
                   dump(context.correlation_id),
                   dump(UUID.generate()),
                   dump(audit_id),
                   %{"kind" => "synthetic"}
                 ]
               )

               :inserted
             end)

    event_id
  end

  defp expire_lease(runtime, context, event_id) do
    update_delivery_time(
      runtime,
      context,
      event_id,
      "lease_expires_at = NOW() - INTERVAL '1 second'"
    )
  end

  defp make_available(runtime, context, event_id) do
    update_delivery_time(runtime, context, event_id, "available_at = NOW() - INTERVAL '1 second'")
  end

  defp update_delivery_time(runtime, context, event_id, expression) do
    assert {:ok, :updated} =
             Persistence.with_writer(runtime, context, fn ->
               Repo.query!(
                 """
                 UPDATE platform_outbox_deliveries
                    SET #{expression}, updated_at = NOW()
                  WHERE tenant_id = $1 AND event_id = $2 AND consumer_key = $3
                 """,
                 [
                   dump(TrustedActor.tenant_id(context.actor)),
                   dump(event_id),
                   @consumer_key
                 ]
               )

               :updated
             end)
  end

  defp insert_delivery_directly(runtime, context, event_id, overrides \\ []) do
    Persistence.with_writer(runtime, context, fn ->
      status = Keyword.get(overrides, :status, "leased")
      lease_token = Keyword.get(overrides, :lease_token, UUID.generate())
      completed_at = Keyword.get(overrides, :completed_at)

      Repo.query(
        """
        INSERT INTO platform_outbox_deliveries (
          id, tenant_id, event_id, consumer_key, status, attempt_count, lock_version,
          lease_token, last_lease_token, lease_expires_at, available_at, failure_code,
          first_claimed_at, last_claimed_at, completed_at, inserted_at, updated_at
        )
        VALUES (
          $1, $2, $3, $4, $5, 1, 1, $6, $6, NOW() + INTERVAL '1 minute',
          NOW(), NULL, NOW(), NOW(), $7, NOW(), NOW()
        )
        """,
        [
          dump(UUID.generate()),
          dump(TrustedActor.tenant_id(context.actor)),
          dump(event_id),
          @consumer_key,
          status,
          dump(lease_token),
          completed_at
        ]
      )
    end)
    |> case do
      {:ok, {:error, error}} -> {:error, error}
      other -> other
    end
  end

  defp clear_tenants(runtime) do
    Enum.each([context_dispatcher_a(), context_dispatcher_b()], fn context ->
      assert {:ok, :cleared} =
               Persistence.with_writer(runtime, context, fn ->
                 tenant_id = TrustedActor.tenant_id(context.actor)

                 Enum.each(
                   @tables,
                   &Repo.query!("DELETE FROM #{&1} WHERE tenant_id = $1", [dump(tenant_id)])
                 )

                 :cleared
               end)
    end)
  end

  defp runtime_options do
    [
      repositories: [pooled: [log: false, pool: DBConnection.ConnectionPool, pool_size: 8]],
      placements: [placement(@tenant_a), placement(@tenant_b)],
      per_tenant_limit: 8,
      per_placement_limit: 16
    ]
  end

  defp placement(tenant_id) do
    [
      tenant_id: tenant_id,
      routing_version: 7,
      profile: :pooled,
      placement_ref: "pooled-outbox-test",
      repository: :pooled
    ]
  end

  defp context_dispatcher_a, do: context(@dispatcher_a, @tenant_a)
  defp context_dispatcher_b, do: context(@dispatcher_b, @tenant_b)
  defp context_dispatch_only_a, do: context(@dispatch_only_a, @tenant_a)
  defp context_observe_only_a, do: context(@observe_only_a, @tenant_a)

  defp context(actor_id, tenant_id) do
    {:ok, actor} =
      TrustedActor.establish(actor_id: actor_id, tenant_id: tenant_id, assurance: "mfa")

    {:ok, placement} =
      TrustedPlacement.establish(
        tenant_id: tenant_id,
        routing_version: 7,
        profile: :pooled,
        placement_ref: "pooled-outbox-test"
      )

    {:ok, context} =
      ExecutionContext.establish(actor, placement,
        correlation_id: UUID.generate(),
        purpose: "platform.outbox.delivery",
        locale: "en"
      )

    context
  end

  defp dump(uuid), do: UUID.dump!(uuid)
end
