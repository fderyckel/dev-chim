defmodule Chimwemwe.Communications.Engagement do
  @moduledoc "Closed Restricted COMM-1 storage; named session-bound actions only."
  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Communications,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table("communications_engagements")
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        unique: true,
        all_tenants?: true,
        name: "communications_engagements_id_tenant_idx"
      )

      index([:tenant_id, :revision_id, :person_id, :kind],
        unique: true,
        all_tenants?: true,
        name: "communications_engagements_unique_0"
      )
    end

    references do
      reference(:notice, on_delete: :restrict, match_tenant?: true, match_type: :full)
      reference(:revision, on_delete: :restrict, match_tenant?: true, match_type: :full)
      reference(:person, on_delete: :restrict, match_tenant?: true, match_type: :full)
    end

    check_constraints do
      check_constraint(:kind, "communications_engagement_kind",
        check:
          "(kind = 'opening' AND statement IS NULL) OR (kind = 'receipt' AND statement IS NOT NULL AND statement = 'I acknowledge receipt of this notice.')"
      )
    end

    custom_statements do
      statement :engagement_immutable do
        global?(true)
        after_tables(["communications_engagements"])

        up("""
        DO $migration$ BEGIN
        CREATE FUNCTION communications_engagements_immutable() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'communication evidence is retained and immutable'; END $$;
        CREATE TRIGGER communications_engagements_immutable BEFORE UPDATE OR DELETE ON communications_engagements
          FOR EACH ROW EXECUTE FUNCTION communications_engagements_immutable();
        END $migration$;
        """)

        down(
          "DO $migration$ BEGIN DROP TRIGGER communications_engagements_immutable ON communications_engagements; DROP FUNCTION communications_engagements_immutable(); END $migration$;"
        )
      end
    end
  end

  multitenancy do
    strategy(:attribute)
    attribute(:tenant_id)
    global?(false)
  end

  relationships do
    belongs_to :notice, Chimwemwe.Communications.Notice do
      source_attribute(:notice_id)
      define_attribute?(false)
      public?(false)
    end

    belongs_to :revision, Chimwemwe.Communications.Revision do
      source_attribute(:revision_id)
      define_attribute?(false)
      public?(false)
    end

    belongs_to :person, Chimwemwe.People.Person do
      source_attribute(:person_id)
      define_attribute?(false)
      public?(false)
    end
  end

  actions do
  end

  policies do
    policy always() do
      forbid_if(always())
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :tenant_id, :uuid do
      allow_nil?(false)
      public?(false)
    end

    attribute :notice_id, :uuid do
      allow_nil?(false)
      public?(false)
    end

    attribute :revision_id, :uuid do
      allow_nil?(false)
      public?(false)
    end

    attribute :person_id, :uuid do
      allow_nil?(false)
      public?(false)
    end

    attribute :actor_id, :uuid do
      allow_nil?(false)
      public?(false)
    end

    attribute :kind, :string do
      allow_nil?(false)
      public?(false)
    end

    attribute :statement, :string do
      allow_nil?(true)
      public?(false)
      sensitive?(true)
    end

    attribute :recorded_at, :utc_datetime_usec do
      allow_nil?(false)
      public?(false)
    end

    create_timestamp(:inserted_at)
  end
end
