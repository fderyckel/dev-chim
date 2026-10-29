defmodule Chimwemwe.People.StaffAccountAssociation do
  @moduledoc "Private tenant-owned StaffAccountAssociation; named People.Foundation operations own access."
  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.People,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "people_staff_account_associations"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "people_staff_account_associations_id_tenant_idx",
        unique: true,
        all_tenants?: true
      )

      index([:person_id, :tenant_id],
        name: "people_staff_account_person_idx",
        unique: true,
        all_tenants?: true,
        where: "revoked_at IS NULL"
      )

      index([:membership_id, :tenant_id],
        name: "people_staff_account_membership_idx",
        unique: true,
        all_tenants?: true,
        where: "revoked_at IS NULL"
      )
    end

    references do
      reference(:person,
        name: "people_staff_account_associations_person_id_fk",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:participation,
        name: "people_staff_account_associations_participation_id_fk",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:membership,
        name: "people_staff_account_associations_membership_id_fk",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint(:lock_version, "people_staff_account_associations_state",
        check:
          "(lock_version = 1 AND revoked_at IS NULL AND revoked_by_actor_id IS NULL) OR (lock_version = 2 AND revoked_at IS NOT NULL AND revoked_by_actor_id IS NOT NULL)"
      )
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  relationships do
    belongs_to :person, Chimwemwe.People.Person do
      source_attribute :person_id
      destination_attribute :id
      define_attribute? false
      public? false
    end

    belongs_to :participation, Chimwemwe.People.Participation do
      source_attribute :participation_id
      destination_attribute :id
      define_attribute? false
      public? false
    end

    belongs_to :membership, Chimwemwe.Platform.Authority.Membership do
      source_attribute :membership_id
      destination_attribute :id
      define_attribute? false
      public? false
    end
  end

  actions do
  end

  policies do
    policy always() do
      forbid_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :tenant_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :person_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :participation_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :membership_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :evidence_reference, :uuid do
      allow_nil? false
      public? false
    end

    attribute :verification, :map do
      allow_nil? false
      public? false
    end

    attribute :revoked_at, :utc_datetime_usec do
      allow_nil? true
      public? false
    end

    attribute :revoked_by_actor_id, :uuid do
      allow_nil? true
      public? false
    end

    attribute :lock_version, :integer do
      allow_nil? false
      public? false
      default 1
      constraints min: 1
    end

    create_timestamp :inserted_at
  end
end
