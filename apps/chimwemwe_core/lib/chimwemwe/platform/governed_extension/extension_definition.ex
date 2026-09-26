defmodule Chimwemwe.Platform.GovernedExtension.ExtensionDefinition do
  @moduledoc """
  Retained tenant-owned presentation configuration pinned to one code-owned contract.

  The resource exposes only a private governed publication action. Stored content
  cannot authorize reads or writes and is not executable.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_governed_extension_definitions"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_governed_extension_definitions_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :module_activation_id, :definition_key],
        name: "platform_governed_extension_definitions_key_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :schema_key, :descriptor_revision],
        name: "platform_governed_extension_definitions_contract_index",
        all_tenants?: true
      )
    end

    references do
      reference(:module_activation,
        name: "platform_governed_extension_definitions_activation_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint(:definition_key, "platform_extension_definition_key_must_be_valid",
        check:
          "char_length(definition_key) BETWEEN 3 AND 120 AND definition_key ~ '^[a-z][a-z0-9_]*([.][a-z][a-z0-9_]*)+$'"
      )

      check_constraint(:schema_key, "platform_extension_schema_key_must_be_valid",
        check:
          "char_length(schema_key) BETWEEN 3 AND 120 AND schema_key ~ '^[a-z][a-z0-9_]*([.][a-z][a-z0-9_]*)+$'"
      )

      check_constraint(:schema_version, "platform_extension_schema_version_must_be_positive",
        check: "schema_version >= 1"
      )

      check_constraint(:module_version, "platform_extension_module_version_must_be_valid",
        check:
          "char_length(module_version) BETWEEN 5 AND 80 AND module_version ~ '^[0-9]+[.][0-9]+[.][0-9]+([+-][0-9A-Za-z.-]+)?$'"
      )

      check_constraint(
        :descriptor_revision,
        "platform_extension_descriptor_revision_must_be_sha256",
        check: "descriptor_revision ~ '^sha256:[0-9a-f]{64}$'"
      )

      check_constraint(:classification, "platform_extension_classification_must_be_known",
        check: "classification IN ('public', 'internal', 'confidential', 'restricted')"
      )

      check_constraint(:content, "platform_extension_content_must_be_an_object",
        check: "jsonb_typeof(content) = 'object'"
      )

      check_constraint(:lock_version, "platform_extension_lock_version_must_be_positive",
        check: "lock_version >= 1"
      )
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  relationships do
    belongs_to :module_activation,
               Chimwemwe.Platform.ModuleLifecycle.ModuleActivation do
      source_attribute :module_activation_id
      destination_attribute :id
      define_attribute? false
      public? false
    end
  end

  actions do
    action :publish_definition, :struct do
      public? false
      transaction? true
      constraints instance_of: Chimwemwe.Platform.GovernedExtension.PublishResult

      argument :definition_id, :uuid do
        allow_nil? false
      end

      argument :definition_key, :string do
        allow_nil? false
        constraints min_length: 3, max_length: 120, trim?: true
      end

      argument :schema_key, :string do
        allow_nil? false
        constraints min_length: 3, max_length: 120, trim?: true
      end

      argument :descriptor_revision, :string do
        allow_nil? false
        constraints min_length: 71, max_length: 71, trim?: true
      end

      argument :content, :map do
        allow_nil? false
      end

      argument :expected_version, :integer do
        allow_nil? false
        constraints min: 0
      end

      argument :idempotency_key, :uuid do
        allow_nil? false
      end

      argument :causation_id, :uuid do
        allow_nil? false
      end

      run Chimwemwe.Platform.GovernedExtension.PublishDefinition
    end
  end

  policies do
    policy action(:publish_definition) do
      forbid_unless actor_present()

      authorize_if {Chimwemwe.Platform.Policy.HasCapability,
                    capability: "platform.extensions.definitions.publish"}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :tenant_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :module_activation_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :definition_key, :string do
      allow_nil? false
      public? false
      constraints min_length: 3, max_length: 120, trim?: true
    end

    attribute :schema_key, :string do
      allow_nil? false
      public? false
      constraints min_length: 3, max_length: 120, trim?: true
    end

    attribute :schema_version, :integer do
      allow_nil? false
      public? false
      constraints min: 1
    end

    attribute :module_version, :string do
      allow_nil? false
      public? false
      constraints min_length: 5, max_length: 80
    end

    attribute :resource_ref, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 120
    end

    attribute :descriptor_revision, :string do
      allow_nil? false
      public? false
      constraints min_length: 71, max_length: 71
    end

    attribute :classification, :atom do
      allow_nil? false
      public? false
      constraints one_of: [:public, :internal, :confidential, :restricted]
    end

    attribute :content, :map do
      allow_nil? false
      public? false
    end

    attribute :lock_version, :integer do
      allow_nil? false
      default 1
      public? false
      constraints min: 1
    end

    attribute :created_by, :uuid do
      allow_nil? false
      public? false
    end

    attribute :updated_by, :uuid do
      allow_nil? false
      public? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
