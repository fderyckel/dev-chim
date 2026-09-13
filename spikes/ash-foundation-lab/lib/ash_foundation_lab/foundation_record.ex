defmodule AshFoundationLab.FoundationRecord do
  @moduledoc """
  Neutral, synthetic tenant-owned record used only by the Phase 0 spike.
  """

  use Ash.Resource,
    otp_app: :ash_foundation_lab,
    domain: AshFoundationLab.Foundation,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  postgres do
    table "foundation_records"
    repo AshFoundationLab.Repo

    custom_indexes do
      index [:tenant_id], name: "foundation_records_tenant_id_index", all_tenants?: true

      index [:id, :tenant_id],
        name: "foundation_records_id_tenant_id_index",
        unique: true,
        all_tenants?: true

      index [:tenant_id, :audit_reference],
        name: "foundation_records_tenant_id_audit_reference_index",
        unique: true,
        where: "audit_reference IS NOT NULL",
        all_tenants?: true
    end

    references do
      reference :tenant,
        name: "foundation_records_tenant_id_fkey",
        on_delete: :restrict
    end

    check_constraints do
      check_constraint :name, "name_must_not_be_empty", check: "char_length(name) > 0"

      check_constraint :status, "foundation_record_status_must_be_known",
        check: "status IN ('draft', 'in_review')"

      check_constraint :lock_version, "foundation_record_lock_version_must_be_positive",
        check: "lock_version >= 1"

      check_constraint [:status, :audit_reference], "submitted_record_requires_audit_reference",
        check: "status <> 'in_review' OR audit_reference IS NOT NULL"
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  relationships do
    belongs_to :tenant, AshFoundationLab.Tenant do
      source_attribute :tenant_id
      destination_attribute :id
      define_attribute? false
      public? false
    end
  end

  json_api do
    type "foundation-record"
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:name]
    end

    update :submit_for_review do
      accept []
      require_atomic? false

      argument :correlation_id, :uuid do
        allow_nil? false
      end

      argument :causation_id, :uuid do
        allow_nil? false
      end

      validate attribute_equals(:status, :draft) do
        message "record must be in draft state"
      end

      change set_attribute(:status, :in_review)
      change optimistic_lock(:lock_version)
      change AshFoundationLab.Change.RecordOutbox
    end
  end

  policies do
    policy always() do
      forbid_unless actor_present()
      forbid_unless AshFoundationLab.Policy.TenantMatchesActor
      authorize_if always()
    end

    policy action(:read) do
      authorize_if {AshFoundationLab.Policy.HasCapability, capability: "foundation_record.read"}
    end

    policy action(:create) do
      authorize_if {AshFoundationLab.Policy.HasCapability, capability: "foundation_record.create"}
    end

    policy action(:submit_for_review) do
      authorize_if {AshFoundationLab.Policy.HasCapability,
                    capability: "foundation_record.submit_for_review"}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :tenant_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :name, :string do
      allow_nil? false
      public? true
      constraints min_length: 1, max_length: 120
    end

    attribute :status, :atom do
      allow_nil? false
      default :draft
      public? true
      constraints one_of: [:draft, :in_review]
    end

    attribute :lock_version, :integer do
      allow_nil? false
      default 1
      public? true
      constraints min: 1
    end

    attribute :audit_reference, :uuid do
      allow_nil? true
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
