defmodule Chimwemwe.Communications.Revision do
  @moduledoc "Closed Restricted COMM-1 storage; named session-bound actions only."
  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Communications,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table("communications_revisions")
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        unique: true,
        all_tenants?: true,
        name: "communications_revisions_id_tenant_idx"
      )

      index([:tenant_id, :notice_id, :number],
        unique: true,
        all_tenants?: true,
        name: "communications_revisions_unique_0"
      )
    end

    references do
      reference(:notice, on_delete: :restrict, match_tenant?: true, match_type: :full)
      reference(:preparation, on_delete: :restrict, match_tenant?: true, match_type: :full)
    end

    check_constraints do
      check_constraint(:eligibility, "communications_revision_eligibility",
        check:
          "COALESCE((jsonb_typeof(eligibility) = 'object' AND jsonb_typeof(eligibility->'audience') = 'number' AND jsonb_typeof(eligibility->'eligible') = 'number' AND jsonb_typeof(eligibility->'no_eligible_account') = 'number' AND jsonb_typeof(eligibility->'no_current_access') = 'number' AND (eligibility->>'audience')::integer BETWEEN 1 AND 25 AND (eligibility->>'eligible')::integer BETWEEN 0 AND 25 AND (eligibility->>'no_eligible_account')::integer BETWEEN 0 AND 25 AND (eligibility->>'no_current_access')::integer BETWEEN 0 AND 25 AND (eligibility->>'audience')::integer = (eligibility->>'eligible')::integer + (eligibility->>'no_eligible_account')::integer + (eligibility->>'no_current_access')::integer),false)"
      )

      check_constraint(:number, "communications_revision_number", check: "number BETWEEN 1 AND 2")

      check_constraint(:approver_id, "communications_independent_approval",
        check: "approver_id <> proposer_id"
      )

      check_constraint(:title, "communications_revision_text",
        check:
          "char_length(title) BETWEEN 1 AND 120 AND char_length(body) BETWEEN 1 AND 2000 AND char_length(reason) <= 240"
      )
    end

    custom_statements do
      statement :revision_immutable do
        global?(true)
        after_tables(["communications_revisions"])

        up("""
        DO $migration$ BEGIN
        CREATE FUNCTION communications_revisions_immutable() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'communication evidence is retained and immutable'; END $$;
        CREATE TRIGGER communications_revisions_immutable BEFORE UPDATE OR DELETE ON communications_revisions
          FOR EACH ROW EXECUTE FUNCTION communications_revisions_immutable();
        END $migration$;
        """)

        down(
          "DO $migration$ BEGIN DROP TRIGGER communications_revisions_immutable ON communications_revisions; DROP FUNCTION communications_revisions_immutable(); END $migration$;"
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

    belongs_to :preparation, Chimwemwe.Communications.Preparation do
      source_attribute(:preparation_id)
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

    attribute :preparation_id, :uuid do
      allow_nil?(false)
      public?(false)
    end

    attribute :number, :integer do
      allow_nil?(false)
      public?(false)
    end

    attribute :proposer_id, :uuid do
      allow_nil?(false)
      public?(false)
    end

    attribute :approver_id, :uuid do
      allow_nil?(false)
      public?(false)
    end

    attribute :title, :string do
      allow_nil?(false)
      public?(false)
      sensitive?(true)
    end

    attribute :body, :string do
      allow_nil?(false)
      public?(false)
      sensitive?(true)
    end

    attribute :reason, :string do
      allow_nil?(false)
      public?(false)
    end

    attribute :receipt_required, :boolean do
      allow_nil?(false)
      public?(false)
    end

    attribute :original_proof, :binary do
      allow_nil?(false)
      public?(false)
      sensitive?(true)
    end

    attribute :eligibility, :map do
      allow_nil?(false)
      public?(false)
      sensitive?(true)
    end

    attribute :published_at, :utc_datetime_usec do
      allow_nil?(false)
      public?(false)
    end

    create_timestamp(:inserted_at)
  end
end
