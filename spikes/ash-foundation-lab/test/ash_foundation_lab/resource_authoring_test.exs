defmodule AshFoundationLab.ResourceAuthoringTest do
  use ExUnit.Case, async: true

  alias AshFoundationLab.Actor
  alias AshFoundationLab.FoundationRecord
  alias AshFoundationLab.GovernedMetadata
  alias AshFoundationLab.Repo
  alias AshFoundationLab.ResourceDescriptor
  alias Ecto.Adapters.SQL.Sandbox
  alias Ecto.UUID

  alias __MODULE__.{RenameV1, RenameV2}

  @descriptor_path Path.expand(
                     "../../priv/resource_descriptors/foundation-record.v1.json",
                     __DIR__
                   )

  setup do
    owner = Sandbox.start_owner!(Repo, shared: false)
    on_exit(fn -> Sandbox.stop_owner(owner) end)

    tenant_a = insert_tenant("Scenario 15 tenant A")
    tenant_b = insert_tenant("Scenario 15 tenant B")
    authorized_actor = insert_actor(tenant_a, "Scenario 15 authorized actor")
    denied_actor = insert_actor(tenant_a, "Scenario 15 denied actor")
    other_tenant_actor = insert_actor(tenant_b, "Scenario 15 other tenant actor")
    grant_capability(tenant_a, authorized_actor.id, "foundation_record.read")
    record_id = insert_record(tenant_a, "Scenario 15 neutral record")
    descriptor = ResourceDescriptor.foundation_record!()

    {:ok,
     %{
       authorized_actor: authorized_actor,
       denied_actor: denied_actor,
       descriptor: descriptor,
       other_tenant_actor: other_tenant_actor,
       record_id: record_id,
       tenant_a: tenant_a,
       tenant_b: tenant_b
     }}
  end

  test "derives and drift-checks a bounded descriptor from the real Ash resource", fixture do
    descriptor = fixture.descriptor

    assert Enum.map(descriptor["fields"], & &1["ref"]) == [
             "foundation_record.id",
             "foundation_record.name",
             "foundation_record.status",
             "foundation_record.lock_version"
           ]

    assert Enum.map(descriptor["actions"], & &1["ref"]) == [
             "foundation_record.list",
             "foundation_record.submit_for_review"
           ]

    refute inspect(descriptor) =~ "tenant_id"
    refute inspect(descriptor) =~ "audit_reference"
    refute inspect(descriptor) =~ "foundation_record.create"
    refute inspect(descriptor) =~ "Elixir.AshFoundationLab.FoundationRecord"

    assert File.read!(@descriptor_path) == ResourceDescriptor.encode!(descriptor)
  end

  test "validates tenant-customized views and reports without duplicating model authority",
       fixture do
    tenant_a_view =
      view_definition(fixture, "Local reference", [
        "foundation_record.name",
        "foundation_record.status"
      ])

    tenant_b_fixture = %{
      fixture
      | tenant_a: fixture.tenant_b,
        authorized_actor: fixture.other_tenant_actor
    }

    tenant_b_view =
      view_definition(tenant_b_fixture, "Community record", [
        "foundation_record.status",
        "foundation_record.name"
      ])

    assert {:ok, ^tenant_a_view} =
             GovernedMetadata.validate_for_write(
               tenant_a_view,
               fixture.descriptor,
               context(fixture.authorized_actor, fixture.tenant_a)
             )

    assert {:ok, ^tenant_b_view} =
             GovernedMetadata.validate_for_write(
               tenant_b_view,
               fixture.descriptor,
               context(fixture.other_tenant_actor, fixture.tenant_b)
             )

    report = report_definition(fixture)

    assert {:ok, ^report} =
             GovernedMetadata.validate_for_write(
               report,
               fixture.descriptor,
               context(fixture.authorized_actor, fixture.tenant_a)
             )

    for definition <- [tenant_a_view, tenant_b_view, report] do
      refute Map.has_key?(definition, "types")
      refute Map.has_key?(definition, "permissions")
      refute Map.has_key?(definition, "policy")
    end
  end

  test "report execution re-enters the policy-protected Ash read action", fixture do
    report = report_definition(fixture)
    filtered_record_id = insert_record(fixture.tenant_a, "Already reviewed", "in_review")

    assert {:ok, records} =
             GovernedMetadata.run_report(
               report,
               fixture.descriptor,
               context(fixture.authorized_actor, fixture.tenant_a)
             )

    assert Enum.map(records, & &1.id) == [fixture.record_id]
    refute filtered_record_id in Enum.map(records, & &1.id)
    assert Enum.all?(records, &match?(%FoundationRecord{}, &1))
  end

  test "metadata cannot grant a denied actor report access", fixture do
    report = report_definition(fixture)

    assert {:error, %Ash.Error.Forbidden{}} =
             GovernedMetadata.run_report(
               report,
               fixture.descriptor,
               context(fixture.denied_actor, fixture.tenant_a)
             )

    forged = Map.put(report, "permissions", ["allow_all"])

    assert {:error, :authority_not_allowed} =
             GovernedMetadata.validate_for_write(
               forged,
               fixture.descriptor,
               context(fixture.authorized_actor, fixture.tenant_a)
             )
  end

  test "cross-tenant definitions fail before reference validation", fixture do
    valid = report_definition(fixture)

    private_reference =
      put_in(valid["columns"], ["foundation_record.tenant_id"])

    for definition <- [valid, private_reference] do
      assert {:error, :tenant_mismatch} =
               GovernedMetadata.validate_for_execution(
                 definition,
                 fixture.descriptor,
                 context(fixture.other_tenant_actor, fixture.tenant_b)
               )
    end
  end

  test "private fields and unapproved actions use one non-disclosing denial", fixture do
    view = view_definition(fixture)

    private_field = put_in(view["fields"], ["foundation_record.tenant_id"])
    policy_field = put_in(view["fields"], ["foundation_record.audit_reference"])
    generic_action = %{view | "primary_action" => "foundation_record.create"}

    for definition <- [private_field, policy_field, generic_action] do
      assert {:error, :reference_not_allowed} =
               GovernedMetadata.validate_for_write(
                 definition,
                 fixture.descriptor,
                 context(fixture.authorized_actor, fixture.tenant_a)
               )
    end
  end

  test "arbitrary SQL, executable content, and authority keys fail closed", fixture do
    report = report_definition(fixture)
    view = view_definition(fixture)

    definitions = [
      Map.put(report, "sql", "SELECT * FROM foundation_records"),
      put_in(report["filters"], [
        %{
          "field" => "foundation_record.status",
          "operator" => "eq",
          "value" => "draft",
          "code" => "system"
        }
      ]),
      Map.put(view, "module", "UntrustedRenderer")
    ]

    for definition <- definitions do
      assert {:error, :executable_content_not_allowed} =
               GovernedMetadata.validate_for_write(
                 definition,
                 fixture.descriptor,
                 context(fixture.authorized_actor, fixture.tenant_a)
               )
    end

    assert {:error, :authority_not_allowed} =
             view
             |> Map.put("authorization", %{"allow" => true})
             |> GovernedMetadata.validate_for_write(
               fixture.descriptor,
               context(fixture.authorized_actor, fixture.tenant_a)
             )
  end

  test "missing trusted context and stale descriptors fail closed", fixture do
    report = report_definition(fixture)

    assert {:error, :missing_trusted_context} =
             GovernedMetadata.validate_for_execution(report, fixture.descriptor, %{})

    stale_report = %{report | "descriptor_revision" => "sha256:stale"}

    assert {:error, :incompatible_descriptor} =
             GovernedMetadata.validate_for_execution(
               stale_report,
               fixture.descriptor,
               context(fixture.authorized_actor, fixture.tenant_a)
             )
  end

  test "a source-field rename requires contract review but preserves stable metadata refs",
       fixture do
    {:ok, descriptor_v1} = ResourceDescriptor.derive(RenameV1, rename_contract(1, :name))

    assert {:error, {:field_not_available, "foundation_record.name"}} =
             ResourceDescriptor.derive(RenameV2, rename_contract(1, :name))

    {:ok, descriptor_v2} =
      ResourceDescriptor.derive(RenameV2, rename_contract(2, :display_name))

    refute descriptor_v1["revision"] == descriptor_v2["revision"]
    definition = view_definition(fixture, "Stable local label", nil, descriptor_v1)

    assert {:ok, upgraded} =
             GovernedMetadata.upgrade_definition(
               definition,
               descriptor_v1,
               descriptor_v2,
               context(fixture.authorized_actor, fixture.tenant_a)
             )

    assert upgraded["descriptor_revision"] == descriptor_v2["revision"]
    assert upgraded["revision"] == definition["revision"] + 1
    assert upgraded["labels"] == definition["labels"]
    assert upgraded["fields"] == definition["fields"]
  end

  test "descriptor evolution rejects removed stable references", fixture do
    {:ok, descriptor_v1} = ResourceDescriptor.derive(RenameV1, rename_contract(1, :name))
    {:ok, descriptor_without_name} = ResourceDescriptor.derive(RenameV2, status_only_contract())
    definition = view_definition(fixture, "Removed field", nil, descriptor_v1)

    assert {:error, :reference_not_allowed} =
             GovernedMetadata.upgrade_definition(
               definition,
               descriptor_v1,
               descriptor_without_name,
               context(fixture.authorized_actor, fixture.tenant_a)
             )
  end

  defp view_definition(fixture, label \\ "Record name", order \\ nil, descriptor \\ nil) do
    descriptor = descriptor || fixture.descriptor
    fields = ["foundation_record.name", "foundation_record.status"]

    %{
      "dataset_ref" => "foundation_records.list",
      "definition_id" => UUID.generate(),
      "descriptor_revision" => descriptor["revision"],
      "fields" => fields,
      "filters" => [
        %{
          "field" => "foundation_record.status",
          "operator" => "eq",
          "value" => "draft"
        }
      ],
      "kind" => "view",
      "labels" => %{"foundation_record.name" => label},
      "order" => order || fields,
      "primary_action" => "foundation_record.submit_for_review",
      "resource_ref" => "foundation_record",
      "revision" => 1,
      "tenant_id" => fixture.tenant_a,
      "title" => "Foundation records",
      "updated_by" => fixture.authorized_actor.id
    }
  end

  defp report_definition(fixture) do
    %{
      "columns" => ["foundation_record.name", "foundation_record.status"],
      "dataset_ref" => "foundation_records.list",
      "definition_id" => UUID.generate(),
      "descriptor_revision" => fixture.descriptor["revision"],
      "filters" => [
        %{
          "field" => "foundation_record.status",
          "operator" => "eq",
          "value" => "draft"
        }
      ],
      "group_by" => ["foundation_record.status"],
      "kind" => "report",
      "labels" => %{"foundation_record.name" => "Reference"},
      "resource_ref" => "foundation_record",
      "revision" => 1,
      "tenant_id" => fixture.tenant_a,
      "title" => "Foundation status report",
      "updated_by" => fixture.authorized_actor.id
    }
  end

  defp rename_contract(model_version, name_source) do
    %{
      schema_version: 1,
      model_version: model_version,
      resource_ref: "foundation_record",
      fields: [
        %{ref: "foundation_record.name", source: name_source, classification: "internal"},
        %{ref: "foundation_record.status", source: :status, classification: "internal"}
      ],
      actions: [
        %{ref: "foundation_record.list", source: :list_records},
        %{ref: "foundation_record.submit_for_review", source: :submit_for_review}
      ],
      datasets: [
        %{
          ref: "foundation_records.list",
          action_ref: "foundation_record.list",
          fields: ["foundation_record.name", "foundation_record.status"],
          filter_fields: ["foundation_record.status"],
          group_fields: ["foundation_record.status"]
        }
      ]
    }
  end

  defp status_only_contract do
    %{
      schema_version: 1,
      model_version: 3,
      resource_ref: "foundation_record",
      fields: [
        %{ref: "foundation_record.status", source: :status, classification: "internal"}
      ],
      actions: [
        %{ref: "foundation_record.list", source: :list_records},
        %{ref: "foundation_record.submit_for_review", source: :submit_for_review}
      ],
      datasets: [
        %{
          ref: "foundation_records.list",
          action_ref: "foundation_record.list",
          fields: ["foundation_record.status"],
          filter_fields: ["foundation_record.status"],
          group_fields: ["foundation_record.status"]
        }
      ]
    }
  end

  defp context(actor, tenant_id), do: %{actor: actor, tenant_id: tenant_id}

  defp insert_tenant(name) do
    id = UUID.generate()

    Repo.query!(
      "INSERT INTO tenants (id, name, inserted_at, updated_at) VALUES ($1, $2, NOW(), NOW())",
      [UUID.dump!(id), name]
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
      [UUID.dump!(id), UUID.dump!(tenant_id), name]
    )

    struct!(Actor, id: id, tenant_id: tenant_id, name: name, kind: :human)
  end

  defp grant_capability(tenant_id, actor_id, capability_key) do
    role_id = UUID.generate()
    capability_id = UUID.generate()

    Repo.query!(
      """
      INSERT INTO roles (id, tenant_id, name, inserted_at, updated_at)
      VALUES ($1, $2, 'Scenario 15 role', NOW(), NOW())
      """,
      [UUID.dump!(role_id), UUID.dump!(tenant_id)]
    )

    Repo.query!(
      """
      INSERT INTO capabilities (id, tenant_id, key, inserted_at, updated_at)
      VALUES ($1, $2, $3, NOW(), NOW())
      """,
      [UUID.dump!(capability_id), UUID.dump!(tenant_id), capability_key]
    )

    Repo.query!(
      """
      INSERT INTO actor_roles (id, tenant_id, actor_id, role_id, inserted_at, updated_at)
      VALUES ($1, $2, $3, $4, NOW(), NOW())
      """,
      [
        UUID.dump!(UUID.generate()),
        UUID.dump!(tenant_id),
        UUID.dump!(actor_id),
        UUID.dump!(role_id)
      ]
    )

    Repo.query!(
      """
      INSERT INTO role_capabilities (
        id, tenant_id, role_id, capability_id, inserted_at, updated_at
      )
      VALUES ($1, $2, $3, $4, NOW(), NOW())
      """,
      [
        UUID.dump!(UUID.generate()),
        UUID.dump!(tenant_id),
        UUID.dump!(role_id),
        UUID.dump!(capability_id)
      ]
    )
  end

  defp insert_record(tenant_id, name, status \\ "draft") do
    id = UUID.generate()
    audit_reference = if status == "in_review", do: UUID.generate(), else: nil

    Repo.query!(
      """
      INSERT INTO foundation_records (
        id, tenant_id, name, status, lock_version, audit_reference, inserted_at, updated_at
      )
      VALUES ($1, $2, $3, $4, 1, $5, NOW(), NOW())
      """,
      [
        UUID.dump!(id),
        UUID.dump!(tenant_id),
        name,
        status,
        audit_reference && UUID.dump!(audit_reference)
      ]
    )

    id
  end
end
