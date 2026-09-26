defmodule Chimwemwe.Platform.GovernedExtensionTest do
  use ExUnit.Case, async: false

  alias Chimwemwe.Platform.{
    ExecutionContext,
    GovernedExtension,
    GovernedExtensionError,
    Persistence,
    PersistenceError,
    PersistenceRuntime,
    TrustedActor,
    TrustedPlacement
  }

  alias Chimwemwe.Platform.GovernedExtension.{DefinitionView, PublishResult, Registry}
  alias Chimwemwe.Platform.ModuleLifecycle.ReleaseManifest
  alias Chimwemwe.Platform.ResourceDescriptorTest.NeutralTenantResource
  alias Chimwemwe.Repo
  alias Ecto.UUID
  alias Postgrex.Error, as: PostgrexError

  @tenant_a "11111111-1111-4111-8111-111111111111"
  @tenant_b "22222222-2222-4222-8222-222222222222"
  @admin_a "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  @admin_b "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
  @denied_a "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
  @module_key "platform.qualification.extensions"
  @schema_key "platform.qualification.records.presentation"
  @publish_capability "platform.extensions.definitions.publish"
  @read_capability "platform.extensions.definitions.read"
  @action_name "platform.extensions.definition.publish"
  @event_type "platform.extensions.definition.published"

  @descriptor_contract %{
    schema_version: 1,
    model_version: 1,
    resource_ref: "neutral_record",
    fields: [
      %{ref: "neutral_record.id", source: :id, classification: :internal},
      %{ref: "neutral_record.name", source: :name, classification: :restricted},
      %{ref: "neutral_record.status", source: :status, classification: :confidential}
    ],
    actions: [
      %{ref: "neutral_record.list", source: :list_records}
    ]
  }

  @tables [
    "platform_governed_extension_definitions",
    "platform_authority_action_idempotency",
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
    fixture = seed_tenants(runtime)
    {:ok, Map.put(fixture, :runtime, runtime)}
  end

  test "release declarations and the registry are immutable, typed, and descriptor-derived" do
    assert {:ok, plain_manifest} = ReleaseManifest.new([release_declaration([])])

    assert {:ok, %{extension_contracts: []}} =
             ReleaseManifest.fetch(plain_manifest, @module_key)

    assert {:error, :extension_contract_not_released} =
             ReleaseManifest.fetch_extension(plain_manifest, @module_key, @schema_key)

    assert {:ok, manifest} = ReleaseManifest.new([release_declaration()])

    assert {:ok, %{key: @schema_key, schema_version: 1}} =
             ReleaseManifest.fetch_extension(manifest, @module_key, @schema_key)

    assert {:error, :invalid_manifest} =
             ReleaseManifest.new([
               release_declaration([
                 %{key: @schema_key, schema_version: 1},
                 %{key: @schema_key, schema_version: 2}
               ])
             ])

    assert {:error, :invalid_manifest} =
             ReleaseManifest.new([
               release_declaration([%{key: @schema_key, schema_version: 0}])
             ])

    registry = registry()
    assert {:ok, declaration} = Registry.fetch(registry, @schema_key)
    assert declaration.descriptor["resource_ref"] == "neutral_record"

    assert declaration.descriptor["tenant_scope"] == %{
             "kind" => "tenant_owned",
             "required" => true
           }

    assert {:ok, normalized, :restricted} =
             Registry.validate_content(declaration, content())

    assert normalized["fields"] == ["neutral_record.id", "neutral_record.name"]

    assert {:error, :invalid_definition} =
             Registry.validate_content(
               declaration,
               Map.put(content(), "authorization", %{"allow" => true})
             )

    assert {:error, :reference_not_allowed} =
             Registry.validate_content(
               declaration,
               %{content() | "fields" => ["neutral_record.private"]}
             )

    assert {:error, :invalid_registry} =
             Registry.new([
               registry_declaration(),
               registry_declaration()
             ])
  end

  test "publishes and revises a classified definition with minimized atomic evidence", fixture do
    input = publish_input()

    assert {:ok, %PublishResult{lock_version: 1, classification: :restricted} = first} =
             publish(fixture.runtime, context_admin_a(), input)

    assert first.id == input.definition_id
    assert first.definition_key == input.definition_key

    assert {:ok,
            [
              [
                1,
                "restricted",
                stored_content,
                0,
                1,
                audit_summary,
                outbox_payload,
                "completed"
              ]
            ]} = read_definition_evidence(fixture.runtime, context_admin_a(), first, input)

    assert stored_content["title"] == "Neutral records"
    assert stored_content["labels"]["neutral_record.name"] == "Display name"
    refute Map.has_key?(audit_summary, "title")
    refute Map.has_key?(audit_summary, "labels")
    refute Map.has_key?(outbox_payload, "title")
    refute Map.has_key?(outbox_payload, "labels")

    revision =
      input
      |> Map.put(:expected_version, 1)
      |> Map.put(:idempotency_key, UUID.generate())
      |> Map.put(:causation_id, UUID.generate())
      |> put_in([:content, "title"], "Configured neutral records")

    assert {:ok, %PublishResult{lock_version: 2, id: id}} =
             publish(fixture.runtime, context_admin_a(), revision)

    assert id == first.id

    assert {:ok, [[2, "Configured neutral records"]]} =
             read_definition(fixture.runtime, context_admin_a(), first.id)
  end

  test "resolves one exact compatible definition into a minimized internal view", fixture do
    input = publish_input()
    assert {:ok, published} = publish(fixture.runtime, context_admin_a(), input)

    assert {:ok,
            %DefinitionView{
              id: id,
              definition_key: "tenant.neutral_records.default_view",
              schema_key: @schema_key,
              schema_version: 1,
              module_key: @module_key,
              published_module_version: "1.0.0",
              active_module_version: "1.0.0",
              resource_ref: "neutral_record",
              descriptor_revision: revision,
              classification: :restricted,
              content: resolved_content,
              lock_version: 1,
              compatibility: :exact
            } = view} =
             GovernedExtension.resolve_definition(
               fixture.runtime,
               manifest(),
               registry(),
               context_admin_a(),
               published.id
             )

    assert id == published.id
    assert revision == descriptor_revision()
    assert resolved_content == content()

    for excluded <- [
          :tenant_id,
          :actor_id,
          :module_activation_id,
          :entitlement_id,
          :placement,
          :repository,
          :audit_reference,
          :event_id
        ] do
      refute Map.has_key?(view, excluded)
    end

    refute function_exported?(GovernedExtension, :list_definitions, 4)
    refute function_exported?(GovernedExtension, :execute_definition, 5)
  end

  test "keeps publication and exact resolution authority separate and tenant-safe", fixture do
    input = publish_input()
    assert {:ok, published} = publish(fixture.runtime, context_admin_a(), input)
    remove_read_grant(fixture.runtime, context_admin_a())

    assert {:error, %GovernedExtensionError{code: :forbidden}} =
             GovernedExtension.resolve_definition(
               fixture.runtime,
               manifest(),
               registry(),
               context_admin_a(),
               published.id
             )

    assert {:ok, %PublishResult{lock_version: 2}} =
             publish(
               fixture.runtime,
               context_admin_a(),
               %{
                 input
                 | content: %{content() | "title" => "Still publishable"},
                   expected_version: 1,
                   idempotency_key: UUID.generate(),
                   causation_id: UUID.generate()
               }
             )

    assert {:error, %GovernedExtensionError{code: :not_found}} =
             GovernedExtension.resolve_definition(
               fixture.runtime,
               manifest(),
               registry(),
               context_admin_b(),
               published.id
             )

    assert {:error, %GovernedExtensionError{code: :invalid_input}} =
             GovernedExtension.resolve_definition(
               fixture.runtime,
               manifest(),
               registry(),
               context_admin_b(),
               "not-a-definition-id"
             )
  end

  test "requires an exact or explicitly compatible active module release", fixture do
    assert {:ok, published} = publish(fixture.runtime, context_admin_a(), publish_input())
    update_activation_version(fixture.runtime, context_admin_a(), fixture.activation_a, "1.1.0")

    incompatible_release =
      release_declaration()
      |> Map.put(:version, "1.1.0")
      |> Map.put(:compatible_from, ["1.1.0"])
      |> manifest()

    assert {:error, %GovernedExtensionError{code: :incompatible_definition}} =
             GovernedExtension.resolve_definition(
               fixture.runtime,
               incompatible_release,
               registry(),
               context_admin_a(),
               published.id
             )

    compatible_release =
      release_declaration()
      |> Map.put(:version, "1.1.0")
      |> Map.put(:compatible_from, ["1.0.0"])
      |> manifest()

    assert {:ok,
            %DefinitionView{
              published_module_version: "1.0.0",
              active_module_version: "1.1.0",
              compatibility: :compatible
            }} =
             GovernedExtension.resolve_definition(
               fixture.runtime,
               compatible_release,
               registry(),
               context_admin_a(),
               published.id
             )

    set_activation_state(fixture.runtime, context_admin_a(), fixture.activation_a, "inactive")

    assert {:error, %GovernedExtensionError{code: :module_gate_failed}} =
             GovernedExtension.resolve_definition(
               fixture.runtime,
               compatible_release,
               registry(),
               context_admin_a(),
               published.id
             )
  end

  test "rejects schema, descriptor, retained-content, and classification drift", fixture do
    assert {:ok, published} = publish(fixture.runtime, context_admin_a(), publish_input())

    changed_descriptor_registry =
      registry_declaration()
      |> Map.put(
        :descriptor_contract,
        Map.put(@descriptor_contract, :model_version, 2)
      )
      |> registry()

    assert {:error, %GovernedExtensionError{code: :incompatible_definition}} =
             GovernedExtension.resolve_definition(
               fixture.runtime,
               manifest(),
               changed_descriptor_registry,
               context_admin_a(),
               published.id
             )

    changed_schema_registry =
      registry_declaration()
      |> Map.put(:schema_version, 2)
      |> registry()

    changed_schema_manifest =
      [%{key: @schema_key, schema_version: 2}]
      |> release_declaration()
      |> manifest()

    assert {:error, %GovernedExtensionError{code: :incompatible_definition}} =
             GovernedExtension.resolve_definition(
               fixture.runtime,
               changed_schema_manifest,
               changed_schema_registry,
               context_admin_a(),
               published.id
             )

    corrupt_definition(
      fixture.runtime,
      context_admin_a(),
      published.id,
      %{content: %{content() | "fields" => ["neutral_record.private"]}}
    )

    assert {:error, %GovernedExtensionError{code: :incompatible_definition}} =
             GovernedExtension.resolve_definition(
               fixture.runtime,
               manifest(),
               registry(),
               context_admin_a(),
               published.id
             )

    corrupt_definition(
      fixture.runtime,
      context_admin_a(),
      published.id,
      %{content: content(), classification: "public"}
    )

    assert {:error, %GovernedExtensionError{code: :incompatible_definition}} =
             GovernedExtension.resolve_definition(
               fixture.runtime,
               manifest(),
               registry(),
               context_admin_a(),
               published.id
             )
  end

  test "fails closed when the exact-resolution persistence runtime is unavailable" do
    {:ok, runtime} = PersistenceRuntime.start_link(runtime_options())
    Process.unlink(runtime)
    :ok = Supervisor.stop(runtime)

    assert {:error, %PersistenceError{code: :retryable_dependency}} =
             GovernedExtension.resolve_definition(
               runtime,
               manifest(),
               registry(),
               context_admin_a(),
               UUID.generate()
             )
  end

  test "returns exact and concurrent replay and rejects changed idempotency reuse", fixture do
    key = UUID.generate()
    input = publish_input(key)

    tasks =
      for _index <- 1..2 do
        Task.async(fn -> publish(fixture.runtime, context_admin_a(), input) end)
      end

    assert [{:ok, first}, {:ok, second}] = Enum.map(tasks, &Task.await(&1, 5_000))
    assert first == second
    assert {:ok, ^first} = publish(fixture.runtime, context_admin_a(), input)

    assert {:error, %GovernedExtensionError{code: :idempotency_conflict}} =
             publish(
               fixture.runtime,
               context_admin_a(),
               put_in(input, [:content, "title"], "Changed request")
             )

    assert {:ok, [[1, 1, 1, 1]]} =
             publication_counts(fixture.runtime, context_admin_a(), first.id, key)
  end

  test "fails closed for stale, private, malformed, undeclared, inactive, and unauthorized input",
       fixture do
    input = publish_input()

    assert {:error, %GovernedExtensionError{code: :stale_descriptor}} =
             GovernedExtension.publish_definition(
               fixture.runtime,
               manifest(),
               registry(),
               context_admin_a(),
               %{input | descriptor_revision: "sha256:" <> String.duplicate("0", 64)}
             )

    assert {:error, %GovernedExtensionError{code: :reference_not_allowed}} =
             publish(
               fixture.runtime,
               context_admin_a(),
               put_in(input, [:content, "fields"], ["neutral_record.private"])
             )

    assert {:error, %GovernedExtensionError{code: :invalid_input}} =
             publish(
               fixture.runtime,
               context_admin_a(),
               Map.put(input, :tenant_id, @tenant_a)
             )

    assert {:error, %GovernedExtensionError{code: :schema_not_available}} =
             GovernedExtension.publish_definition(
               fixture.runtime,
               plain_manifest(),
               registry(),
               context_admin_a(),
               input
             )

    assert {:error, %GovernedExtensionError{code: :forbidden}} =
             publish(fixture.runtime, context_denied_a(), input)

    set_activation_state(fixture.runtime, context_admin_a(), fixture.activation_a, "inactive")

    assert {:error, %GovernedExtensionError{code: :module_gate_failed}} =
             publish(fixture.runtime, context_admin_a(), input)

    assert {:ok, [[0, 0, 0, 0]]} =
             publication_counts(
               fixture.runtime,
               context_admin_a(),
               input.definition_id,
               input.idempotency_key
             )
  end

  test "keeps release, entitlement, activation version, dependency, and capability gates independent",
       fixture do
    input = publish_input()

    {:ok, dependency_manifest} =
      ReleaseManifest.new([
        %{
          dependencies: [],
          key: "platform.qualification.base",
          owner: "Platform engineering",
          version: "1.0.0"
        },
        %{release_declaration() | dependencies: ["platform.qualification.base"]}
      ])

    assert {:error, %GovernedExtensionError{code: :module_gate_failed}} =
             GovernedExtension.publish_definition(
               fixture.runtime,
               dependency_manifest,
               registry(),
               context_admin_a(),
               input
             )

    update_activation_version(fixture.runtime, context_admin_a(), fixture.activation_a, "2.0.0")

    assert {:error, %GovernedExtensionError{code: :module_gate_failed}} =
             publish(fixture.runtime, context_admin_a(), input)

    update_activation_version(fixture.runtime, context_admin_a(), fixture.activation_a, "1.0.0")
    delete_activation(fixture.runtime, context_admin_a(), fixture.activation_a)

    assert {:error, %GovernedExtensionError{code: :module_gate_failed}} =
             publish(fixture.runtime, context_admin_a(), input)

    delete_entitlement(fixture.runtime, context_admin_a())

    assert {:error, %GovernedExtensionError{code: :module_gate_failed}} =
             publish(fixture.runtime, context_admin_a(), input)

    assert {:ok, [[0, 0, 0, 0]]} =
             publication_counts(
               fixture.runtime,
               context_admin_a(),
               input.definition_id,
               input.idempotency_key
             )
  end

  test "does not disclose another tenant and the database rejects cross-tenant activation links",
       fixture do
    input = publish_input()
    assert {:ok, first} = publish(fixture.runtime, context_admin_a(), input)

    assert {:error, %GovernedExtensionError{code: :not_found}} =
             publish(
               fixture.runtime,
               context_admin_b(),
               %{
                 input
                 | expected_version: 1,
                   idempotency_key: UUID.generate(),
                   causation_id: UUID.generate()
               }
             )

    assert {:ok, :checked} =
             Persistence.with_writer(fixture.runtime, context_admin_a(), fn ->
               error =
                 assert_raise PostgrexError, fn ->
                   insert_definition_directly(@tenant_a, fixture.activation_b)
                 end

               assert error.postgres.constraint ==
                        "platform_governed_extension_definitions_activation_tenant_fkey"

               :checked
             end)

    assert {:ok, [[1, 1, 1, 1]]} =
             publication_counts(
               fixture.runtime,
               context_admin_a(),
               first.id,
               input.idempotency_key
             )
  end

  test "database constraints reject malformed contracts, classifications, content, and versions",
       fixture do
    invalid_rows = [
      {[definition_key: "invalid"], "platform_extension_definition_key_must_be_valid"},
      {[schema_version: 0], "platform_extension_schema_version_must_be_positive"},
      {[module_version: "version-one"], "platform_extension_module_version_must_be_valid"},
      {[descriptor_revision: "not-a-digest"],
       "platform_extension_descriptor_revision_must_be_sha256"},
      {[classification: "secret"], "platform_extension_classification_must_be_known"},
      {[content: []], "platform_extension_content_must_be_an_object"},
      {[lock_version: 0], "platform_extension_lock_version_must_be_positive"}
    ]

    assert {:ok, :checked} =
             Persistence.with_writer(fixture.runtime, context_admin_a(), fn ->
               for {overrides, constraint} <- invalid_rows do
                 error =
                   capture_postgrex_error(constraint, fn ->
                     insert_definition_directly(@tenant_a, fixture.activation_a, overrides)
                   end)

                 assert error.postgres.constraint == constraint
               end

               :checked
             end)
  end

  defp capture_postgrex_error(expected_constraint, operation) do
    operation.()
    flunk("expected database constraint #{expected_constraint}")
  rescue
    error in PostgrexError -> error
  end

  test "rolls definition and every fact back after a post-outbox failure", fixture do
    input = publish_input()
    install_completion_failure(fixture.runtime)
    on_exit(fn -> remove_completion_failure(fixture.runtime) end)

    assert {:error, %GovernedExtensionError{code: :retryable_dependency}} =
             publish(fixture.runtime, context_admin_a(), input)

    assert {:ok, [[0, 0, 0, 0]]} =
             publication_counts(
               fixture.runtime,
               context_admin_a(),
               input.definition_id,
               input.idempotency_key
             )

    remove_completion_failure(fixture.runtime)

    assert {:ok, %PublishResult{lock_version: 1}} =
             publish(fixture.runtime, context_admin_a(), input)
  end

  defp publish(runtime, context, input) do
    GovernedExtension.publish_definition(runtime, manifest(), registry(), context, input)
  end

  defp manifest(declaration \\ release_declaration()) do
    {:ok, manifest} = ReleaseManifest.new([declaration])
    manifest
  end

  defp plain_manifest do
    {:ok, manifest} = ReleaseManifest.new([release_declaration([])])
    manifest
  end

  defp release_declaration(extensions \\ [%{key: @schema_key, schema_version: 1}]) do
    %{
      dependencies: [],
      extension_contracts: extensions,
      key: @module_key,
      owner: "Platform engineering",
      version: "1.0.0"
    }
  end

  defp registry(declaration \\ registry_declaration()) do
    {:ok, registry} = Registry.new([declaration])
    registry
  end

  defp registry_declaration do
    %{
      descriptor_contract: @descriptor_contract,
      kind: :presentation,
      module_key: @module_key,
      resource: NeutralTenantResource,
      schema_key: @schema_key,
      schema_version: 1
    }
  end

  defp descriptor_revision do
    {:ok, declaration} = Registry.fetch(registry(), @schema_key)
    declaration.descriptor["revision"]
  end

  defp content do
    %{
      "fields" => ["neutral_record.id", "neutral_record.name"],
      "labels" => %{
        "neutral_record.id" => "Reference",
        "neutral_record.name" => "Display name"
      },
      "read_action" => "neutral_record.list",
      "title" => "Neutral records"
    }
  end

  defp publish_input(idempotency_key \\ UUID.generate()) do
    %{
      causation_id: UUID.generate(),
      content: content(),
      definition_id: UUID.generate(),
      definition_key: "tenant.neutral_records.default_view",
      descriptor_revision: descriptor_revision(),
      expected_version: 0,
      idempotency_key: idempotency_key,
      schema_key: @schema_key
    }
  end

  defp seed_tenants(runtime) do
    tenant_a = seed_tenant(runtime, context_admin_a(), @tenant_a, @admin_a, true)
    tenant_b = seed_tenant(runtime, context_admin_b(), @tenant_b, @admin_b, true)
    seed_membership(runtime, context_admin_a(), @tenant_a, @denied_a)

    %{
      activation_a: tenant_a.activation_id,
      activation_b: tenant_b.activation_id
    }
  end

  defp seed_tenant(runtime, context, tenant_id, actor_id, grant?) do
    ids = %{
      activation_id: UUID.generate(),
      capability_id: UUID.generate(),
      entitlement_id: UUID.generate(),
      membership_id: UUID.generate(),
      read_capability_id: UUID.generate(),
      role_id: UUID.generate()
    }

    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context, fn ->
               insert_membership(ids.membership_id, tenant_id, actor_id)
               insert_role(ids.role_id, tenant_id)
               insert_capability(ids.capability_id, tenant_id, @publish_capability)
               insert_capability(ids.read_capability_id, tenant_id, @read_capability)
               insert_assignment(tenant_id, ids.membership_id, ids.role_id)

               if grant? do
                 insert_grant(tenant_id, ids.role_id, ids.capability_id)
                 insert_grant(tenant_id, ids.role_id, ids.read_capability_id)
               end

               insert_entitlement(ids.entitlement_id, tenant_id)
               insert_activation(ids.activation_id, ids.entitlement_id, tenant_id)
               :seeded
             end)

    ids
  end

  defp seed_membership(runtime, context, tenant_id, actor_id) do
    assert {:ok, :seeded} =
             Persistence.with_writer(runtime, context, fn ->
               insert_membership(UUID.generate(), tenant_id, actor_id)
               :seeded
             end)
  end

  defp insert_membership(id, tenant_id, actor_id) do
    Repo.query!(
      """
      INSERT INTO platform_tenant_memberships (id, tenant_id, actor_id, inserted_at, updated_at)
      VALUES ($1, $2, $3, NOW(), NOW())
      """,
      Enum.map([id, tenant_id, actor_id], &dump/1)
    )
  end

  defp insert_role(id, tenant_id) do
    Repo.query!(
      """
      INSERT INTO platform_roles (id, tenant_id, name, lock_version, inserted_at, updated_at)
      VALUES ($1, $2, $3, 1, NOW(), NOW())
      """,
      [dump(id), dump(tenant_id), "Extension publisher"]
    )
  end

  defp insert_capability(id, tenant_id, capability) do
    Repo.query!(
      """
      INSERT INTO platform_capabilities (id, tenant_id, key, inserted_at, updated_at)
      VALUES ($1, $2, $3, NOW(), NOW())
      """,
      [dump(id), dump(tenant_id), capability]
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

  defp insert_entitlement(id, tenant_id) do
    Repo.query!(
      """
      INSERT INTO platform_module_entitlements (id, tenant_id, module_key, inserted_at)
      VALUES ($1, $2, $3, NOW())
      """,
      [dump(id), dump(tenant_id), @module_key]
    )
  end

  defp insert_activation(id, entitlement_id, tenant_id) do
    Repo.query!(
      """
      INSERT INTO platform_module_activations (
        id, tenant_id, entitlement_id, module_version, state, lock_version,
        activated_at, inserted_at, updated_at
      )
      VALUES ($1, $2, $3, '1.0.0', 'active', 1, NOW(), NOW(), NOW())
      """,
      Enum.map([id, tenant_id, entitlement_id], &dump/1)
    )
  end

  defp set_activation_state(runtime, context, activation_id, state) do
    assert {:ok, :updated} =
             Persistence.with_writer(runtime, context, fn ->
               Repo.query!(
                 """
                 UPDATE platform_module_activations
                 SET state = $3,
                     replay_from_cursor = CASE WHEN $3 = 'inactive' THEN consumer_cursor ELSE NULL END,
                     projection_ready = $3 = 'active',
                     reconciliation_required = $3 = 'inactive',
                     deactivated_at = CASE WHEN $3 = 'inactive' THEN NOW() ELSE deactivated_at END,
                     updated_at = NOW()
                 WHERE id = $1 AND tenant_id = $2
                 """,
                 [
                   dump(activation_id),
                   dump(TrustedActor.tenant_id(context.actor)),
                   state
                 ]
               )

               :updated
             end)
  end

  defp update_activation_version(runtime, context, activation_id, version) do
    assert {:ok, :updated} =
             Persistence.with_writer(runtime, context, fn ->
               Repo.query!(
                 """
                 UPDATE platform_module_activations
                 SET module_version = $3, updated_at = NOW()
                 WHERE id = $1 AND tenant_id = $2
                 """,
                 [dump(activation_id), dump(TrustedActor.tenant_id(context.actor)), version]
               )

               :updated
             end)
  end

  defp delete_activation(runtime, context, activation_id) do
    assert {:ok, :deleted} =
             Persistence.with_writer(runtime, context, fn ->
               Repo.query!(
                 "DELETE FROM platform_module_activations WHERE id = $1 AND tenant_id = $2",
                 [dump(activation_id), dump(TrustedActor.tenant_id(context.actor))]
               )

               :deleted
             end)
  end

  defp delete_entitlement(runtime, context) do
    assert {:ok, :deleted} =
             Persistence.with_writer(runtime, context, fn ->
               Repo.query!(
                 "DELETE FROM platform_module_entitlements WHERE tenant_id = $1 AND module_key = $2",
                 [dump(TrustedActor.tenant_id(context.actor)), @module_key]
               )

               :deleted
             end)
  end

  defp remove_read_grant(runtime, context) do
    assert {:ok, :removed} =
             Persistence.with_writer(runtime, context, fn ->
               Repo.query!(
                 """
                 DELETE FROM platform_role_capability_grants AS role_grant
                 USING platform_capabilities AS capability
                 WHERE role_grant.tenant_id = $1
                   AND capability.tenant_id = role_grant.tenant_id
                   AND capability.id = role_grant.capability_id
                   AND capability.key = $2
                 """,
                 [dump(TrustedActor.tenant_id(context.actor)), @read_capability]
               )

               :removed
             end)
  end

  defp corrupt_definition(runtime, context, definition_id, overrides) do
    assert {:ok, :corrupted} =
             Persistence.with_writer(runtime, context, fn ->
               Repo.query!(
                 """
                 UPDATE platform_governed_extension_definitions
                 SET content = COALESCE($3::jsonb, content),
                     classification = COALESCE($4, classification),
                     updated_at = NOW()
                 WHERE tenant_id = $1 AND id = $2
                 """,
                 [
                   dump(TrustedActor.tenant_id(context.actor)),
                   dump(definition_id),
                   Map.get(overrides, :content),
                   Map.get(overrides, :classification)
                 ]
               )

               :corrupted
             end)
  end

  defp read_definition_evidence(runtime, context, result, input) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT definition.lock_version, definition.classification, definition.content,
               audit.before_version, audit.after_version, audit.change_summary,
               outbox.payload, claim.status
        FROM platform_governed_extension_definitions AS definition
        JOIN platform_authority_audit_events AS audit
          ON audit.tenant_id = definition.tenant_id AND audit.id = $3
        JOIN platform_outbox_events AS outbox
          ON outbox.tenant_id = definition.tenant_id AND outbox.id = $4
        JOIN platform_authority_action_idempotency AS claim
          ON claim.tenant_id = definition.tenant_id AND claim.idempotency_key = $5
        WHERE definition.tenant_id = $1 AND definition.id = $2
        """,
        Enum.map(
          [
            TrustedActor.tenant_id(context.actor),
            result.id,
            result.audit_reference,
            result.event_id,
            input.idempotency_key
          ],
          &dump/1
        )
      ).rows
    end)
  end

  defp read_definition(runtime, context, definition_id) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT lock_version, content->>'title'
        FROM platform_governed_extension_definitions
        WHERE tenant_id = $1 AND id = $2
        """,
        [dump(TrustedActor.tenant_id(context.actor)), dump(definition_id)]
      ).rows
    end)
  end

  defp publication_counts(runtime, context, definition_id, idempotency_key) do
    Persistence.with_writer(runtime, context, fn ->
      Repo.query!(
        """
        SELECT
          (SELECT count(*) FROM platform_governed_extension_definitions
           WHERE tenant_id = $1 AND id = $2),
          (SELECT count(*) FROM platform_authority_audit_events
           WHERE tenant_id = $1 AND aggregate_id = $2 AND action_name = $4),
          (SELECT count(*) FROM platform_outbox_events
           WHERE tenant_id = $1 AND aggregate_id = $2 AND event_type = $5),
          (SELECT count(*) FROM platform_authority_action_idempotency
           WHERE tenant_id = $1 AND aggregate_id = $2 AND idempotency_key = $3 AND action_name = $4)
        """,
        [
          dump(TrustedActor.tenant_id(context.actor)),
          dump(definition_id),
          dump(idempotency_key),
          @action_name,
          @event_type
        ]
      ).rows
    end)
  end

  defp insert_definition_directly(tenant_id, activation_id, overrides \\ []) do
    definition_key = Keyword.get(overrides, :definition_key, "tenant.direct.invalid")
    schema_version = Keyword.get(overrides, :schema_version, 1)
    module_version = Keyword.get(overrides, :module_version, "1.0.0")
    descriptor_revision = Keyword.get(overrides, :descriptor_revision, descriptor_revision())
    classification = Keyword.get(overrides, :classification, "internal")
    content = Keyword.get(overrides, :content, %{})
    lock_version = Keyword.get(overrides, :lock_version, 1)

    Repo.query!(
      """
      INSERT INTO platform_governed_extension_definitions (
        id, tenant_id, module_activation_id, definition_key, schema_key, schema_version,
        module_version, resource_ref, descriptor_revision, classification, content,
        lock_version, created_by, updated_by, inserted_at, updated_at
      )
      VALUES (
        $1, $2, $3, $4, $5, $6, $7, 'neutral_record',
        $8, $9, $10::jsonb, $11, $12, $12, NOW(), NOW()
      )
      """,
      [
        dump(UUID.generate()),
        dump(tenant_id),
        dump(activation_id),
        definition_key,
        @schema_key,
        schema_version,
        module_version,
        descriptor_revision,
        classification,
        content,
        lock_version,
        dump(@admin_a)
      ]
    )
  end

  defp install_completion_failure(runtime) do
    assert {:ok, :installed} =
             Persistence.with_writer(runtime, context_admin_a(), fn ->
               remove_failure_objects()

               Repo.query!("""
               CREATE FUNCTION test_fail_extension_idempotency_completion()
               RETURNS trigger
               LANGUAGE plpgsql
               AS $$
               BEGIN
                 IF NEW.status = 'completed' AND NEW.action_name = '#{@action_name}' THEN
                   RAISE EXCEPTION USING ERRCODE = '40001', MESSAGE = 'synthetic extension failure';
                 END IF;
                 RETURN NEW;
               END;
               $$;
               """)

               Repo.query!("""
               CREATE TRIGGER test_fail_extension_idempotency_completion
               BEFORE UPDATE OF status ON platform_authority_action_idempotency
               FOR EACH ROW EXECUTE FUNCTION test_fail_extension_idempotency_completion();
               """)

               :installed
             end)
  end

  defp remove_completion_failure(runtime) do
    Persistence.with_writer(runtime, context_admin_a(), fn ->
      remove_failure_objects()
      :removed
    end)
  end

  defp remove_failure_objects do
    Repo.query!(
      "DROP TRIGGER IF EXISTS test_fail_extension_idempotency_completion ON platform_authority_action_idempotency"
    )

    Repo.query!("DROP FUNCTION IF EXISTS test_fail_extension_idempotency_completion()")
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
               Enum.each(@tables, &delete_tenant_rows(&1, tenant_id))
               :cleared
             end)
  end

  defp delete_tenant_rows(table, tenant_id) do
    Repo.query!("DELETE FROM #{table} WHERE tenant_id = $1", [dump(tenant_id)])
  end

  defp runtime_options do
    [
      repositories: [pooled: [log: false, pool: DBConnection.ConnectionPool, pool_size: 6]],
      placements: [
        placement(@tenant_a),
        placement(@tenant_b)
      ],
      per_tenant_limit: 6,
      per_placement_limit: 12
    ]
  end

  defp placement(tenant_id) do
    [
      tenant_id: tenant_id,
      routing_version: 7,
      profile: :pooled,
      placement_ref: "pooled-governed-extension",
      repository: :pooled
    ]
  end

  defp context_admin_a, do: context(@admin_a, @tenant_a)
  defp context_admin_b, do: context(@admin_b, @tenant_b)
  defp context_denied_a, do: context(@denied_a, @tenant_a)

  defp context(actor_id, tenant_id) do
    {:ok, actor} =
      TrustedActor.establish(actor_id: actor_id, tenant_id: tenant_id, assurance: "mfa")

    {:ok, placement} =
      TrustedPlacement.establish(
        tenant_id: tenant_id,
        routing_version: 7,
        profile: :pooled,
        placement_ref: "pooled-governed-extension"
      )

    {:ok, context} =
      ExecutionContext.establish(
        actor,
        placement,
        correlation_id: UUID.generate(),
        purpose: @action_name,
        locale: "en"
      )

    context
  end

  defp dump(uuid), do: UUID.dump!(uuid)
end
