defmodule Chimwemwe.Platform.ResourceDescriptorTest do
  use ExUnit.Case, async: true

  alias Chimwemwe.Platform.ResourceDescriptor

  alias __MODULE__.{
    NeutralGlobalReference,
    NeutralTenantResource,
    RenameV1,
    RenameV2
  }

  @tenant_contract %{
    schema_version: 1,
    model_version: 1,
    resource_ref: "neutral_record",
    fields: [
      %{ref: "neutral_record.status", source: :status, classification: :confidential},
      %{ref: "neutral_record.id", source: :id, classification: :internal},
      %{ref: "neutral_record.rank", source: :rank, classification: :public},
      %{ref: "neutral_record.name", source: :name, classification: :restricted}
    ],
    actions: [
      %{ref: "neutral_record.request_review", source: :submit_for_review},
      %{ref: "neutral_record.list", source: :list_records}
    ]
  }

  @global_contract %{
    schema_version: 1,
    model_version: 1,
    resource_ref: "reference_value",
    fields: [
      %{ref: "reference_value.code", source: :code, classification: :public}
    ],
    actions: [
      %{ref: "reference_value.list", source: :list_reference_values}
    ]
  }

  test "derives a bounded tenant-owned descriptor from an explicit allowlist" do
    assert {:ok, descriptor} = ResourceDescriptor.derive(NeutralTenantResource, @tenant_contract)

    assert descriptor["schema_version"] == 1
    assert descriptor["model_version"] == 1
    assert descriptor["resource_ref"] == "neutral_record"
    assert descriptor["tenant_scope"] == %{"kind" => "tenant_owned", "required" => true}

    assert Enum.map(descriptor["fields"], & &1["ref"]) == [
             "neutral_record.id",
             "neutral_record.name",
             "neutral_record.rank",
             "neutral_record.status"
           ]

    assert Enum.map(descriptor["fields"], & &1["classification"]) == [
             "internal",
             "restricted",
             "public",
             "confidential"
           ]

    assert Enum.map(descriptor["actions"], & &1["ref"]) == [
             "neutral_record.list",
             "neutral_record.request_review"
           ]

    assert descriptor["revision"] =~ ~r/\Asha256:[0-9a-f]{64}\z/
  end

  test "derives global scope from the code-owned resource contract" do
    assert {:ok, descriptor} =
             ResourceDescriptor.derive(NeutralGlobalReference, @global_contract)

    assert descriptor["tenant_scope"] == %{
             "kind" => "global_reference",
             "required" => false
           }
  end

  test "includes portable constraints, pagination, and public action arguments only" do
    assert {:ok, descriptor} = ResourceDescriptor.derive(NeutralTenantResource, @tenant_contract)

    name = field(descriptor, "neutral_record.name")
    status = field(descriptor, "neutral_record.status")
    rank = field(descriptor, "neutral_record.rank")
    list = action(descriptor, "neutral_record.list")
    submit = action(descriptor, "neutral_record.request_review")

    assert name["type"] == "string"

    assert name["constraints"] == %{
             "allow_empty?" => false,
             "max_length" => 120,
             "min_length" => 1,
             "trim?" => true
           }

    assert status["type"] == "enum"
    assert status["constraints"] == %{"one_of" => ["draft", "in_review"]}
    assert rank["constraints"] == %{"max" => 10, "min" => 1}

    assert list["pagination"] == %{
             "default_limit" => 25,
             "keyset" => true,
             "max_page_size" => 100,
             "required" => false
           }

    assert Enum.map(list["arguments"], & &1["ref"]) == ["status"]
    assert Enum.map(submit["arguments"], & &1["ref"]) == ["note"]
  end

  test "does not serialize private model or framework authority" do
    assert {:ok, descriptor} = ResourceDescriptor.derive(NeutralTenantResource, @tenant_contract)

    encoded = ResourceDescriptor.encode!(descriptor)

    refute encoded =~ "tenant_id"
    refute encoded =~ "audit_reference"
    refute encoded =~ "internal_probe"
    refute encoded =~ "Elixir."
    refute encoded =~ "NeutralTenantResource"
    refute encoded =~ "submit_for_review\""
    refute encoded =~ "Ash.Policy.Authorizer"
    refute encoded =~ "data_layer"
  end

  test "canonical ordering makes equivalent allowlists byte-for-byte stable" do
    reordered = %{
      actions: Enum.reverse(@tenant_contract.actions),
      fields: Enum.reverse(@tenant_contract.fields),
      resource_ref: @tenant_contract.resource_ref,
      model_version: @tenant_contract.model_version,
      schema_version: @tenant_contract.schema_version
    }

    assert {:ok, descriptor} = ResourceDescriptor.derive(NeutralTenantResource, @tenant_contract)
    assert {:ok, same_descriptor} = ResourceDescriptor.derive(NeutralTenantResource, reordered)
    assert descriptor == same_descriptor
    assert ResourceDescriptor.encode!(descriptor) == ResourceDescriptor.encode!(same_descriptor)
  end

  test "a source rename can preserve stable references while model evolution changes revision" do
    contract_v1 = rename_contract(1, :name)
    renamed_source_contract = rename_contract(1, :display_name)
    contract_v2 = rename_contract(2, :display_name)

    assert {:ok, descriptor_v1} = ResourceDescriptor.derive(RenameV1, contract_v1)

    assert {:ok, renamed_source_descriptor} =
             ResourceDescriptor.derive(RenameV2, renamed_source_contract)

    assert {:ok, descriptor_v2} = ResourceDescriptor.derive(RenameV2, contract_v2)

    assert descriptor_v1 == renamed_source_descriptor

    assert Enum.map(descriptor_v1["fields"], & &1["ref"]) ==
             Enum.map(descriptor_v2["fields"], & &1["ref"])

    assert descriptor_v1["revision"] != descriptor_v2["revision"]
  end

  test "rejects resources that do not satisfy the production resource contract" do
    assert {:error, {:resource_contract_invalid, [:not_an_ash_resource]}} =
             ResourceDescriptor.derive(String, @tenant_contract)

    unowned = Chimwemwe.Platform.ResourceContractTest.UnownedResource

    assert {:error, {:resource_contract_invalid, violations}} =
             ResourceDescriptor.derive(unowned, @tenant_contract)

    assert :missing_resource_contract in violations
    assert :missing_policy_authorizer in violations
  end

  test "rejects private, missing, and unsupported fields without exposing them" do
    contracts = [
      put_in(@tenant_contract.fields, [
        %{ref: "neutral_record.audit", source: :audit_reference, classification: :internal}
      ]),
      put_in(@tenant_contract.fields, [
        %{ref: "neutral_record.missing", source: :missing, classification: :internal}
      ]),
      put_in(@tenant_contract.fields, [
        %{ref: "neutral_record.payload", source: :payload, classification: :internal}
      ])
    ]

    assert {:error, {:field_not_available, "neutral_record.audit"}} =
             ResourceDescriptor.derive(NeutralTenantResource, Enum.at(contracts, 0))

    assert {:error, {:field_not_available, "neutral_record.missing"}} =
             ResourceDescriptor.derive(NeutralTenantResource, Enum.at(contracts, 1))

    assert {:error, {:field_type_not_supported, "neutral_record.payload"}} =
             ResourceDescriptor.derive(NeutralTenantResource, Enum.at(contracts, 2))
  end

  test "rejects private, missing, generic, and unsupported actions" do
    assert {:error, {:action_not_available, "neutral_record.private"}} =
             ResourceDescriptor.derive(
               NeutralTenantResource,
               put_in(@tenant_contract.actions, [
                 %{ref: "neutral_record.private", source: :private_records}
               ])
             )

    assert {:error, {:action_not_available, "neutral_record.missing"}} =
             ResourceDescriptor.derive(
               NeutralTenantResource,
               put_in(@tenant_contract.actions, [
                 %{ref: "neutral_record.missing", source: :missing}
               ])
             )

    assert {:error, {:generic_mutation_reference, "neutral_record.update"}} =
             ResourceDescriptor.derive(
               NeutralTenantResource,
               put_in(@tenant_contract.actions, [
                 %{ref: "neutral_record.update", source: :submit_for_review}
               ])
             )

    assert {:error, {:argument_type_not_supported, :payload}} =
             ResourceDescriptor.derive(
               NeutralTenantResource,
               put_in(@tenant_contract.actions, [
                 %{ref: "neutral_record.submit_payload", source: :submit_with_payload}
               ])
             )
  end

  test "rejects malformed versions, references, classifications, and authority-shaped extras" do
    invalid_contracts = [
      %{@tenant_contract | schema_version: 2},
      %{@tenant_contract | model_version: 0},
      %{@tenant_contract | resource_ref: "NeutralRecord"},
      Map.put(@tenant_contract, :tenant_scope, %{kind: :global_reference}),
      put_in(@tenant_contract.fields, [
        %{ref: "other_record.name", source: :name, classification: :internal}
      ]),
      put_in(@tenant_contract.fields, [
        %{ref: "neutral_record.name", source: :name, classification: :secret}
      ]),
      put_in(@tenant_contract.actions, [
        %{ref: "other_record.list", source: :list_records}
      ])
    ]

    for contract <- invalid_contracts do
      assert {:error, _reason} = ResourceDescriptor.derive(NeutralTenantResource, contract)
    end
  end

  test "rejects duplicate source mappings and duplicate public references" do
    duplicate_field_source = %{
      @tenant_contract
      | fields: [
          %{ref: "neutral_record.name", source: :name, classification: :internal},
          %{ref: "neutral_record.label", source: :name, classification: :internal}
        ]
    }

    duplicate_action_source = %{
      @tenant_contract
      | actions: [
          %{ref: "neutral_record.list", source: :list_records},
          %{ref: "neutral_record.search", source: :list_records}
        ]
    }

    duplicate_public_ref = %{
      @tenant_contract
      | fields: [
          %{ref: "neutral_record.list", source: :name, classification: :internal}
        ],
        actions: [
          %{ref: "neutral_record.list", source: :list_records}
        ]
    }

    assert {:error, {:duplicate_source, :field}} =
             ResourceDescriptor.derive(NeutralTenantResource, duplicate_field_source)

    assert {:error, {:duplicate_source, :action}} =
             ResourceDescriptor.derive(NeutralTenantResource, duplicate_action_source)

    assert {:error, :duplicate_stable_reference} =
             ResourceDescriptor.derive(NeutralTenantResource, duplicate_public_ref)
  end

  defp field(descriptor, ref), do: Enum.find(descriptor["fields"], &(&1["ref"] == ref))
  defp action(descriptor, ref), do: Enum.find(descriptor["actions"], &(&1["ref"] == ref))

  defp rename_contract(model_version, source) do
    %{
      schema_version: 1,
      model_version: model_version,
      resource_ref: "rename_record",
      fields: [
        %{ref: "rename_record.name", source: source, classification: :internal}
      ],
      actions: [
        %{ref: "rename_record.list", source: :list_records}
      ]
    }
  end
end
