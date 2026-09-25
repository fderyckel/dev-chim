defmodule Chimwemwe.Platform.TemporalQualification.Fact do
  @moduledoc """
  Immutable append-only fact for the neutral ADR 0018 qualification proof.

  A reversal is another fact in the same tenant and scope. A replacement may
  share the reversal's operation identity, so operation identity is indexed but
  intentionally not unique.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_temporal_qualification_facts"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_temporal_qualification_facts_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:id, :tenant_id, :scope_id],
        name: "platform_temporal_qualification_facts_scope_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :scope_id, :recorded_at, :id],
        name: "platform_temporal_qualification_fact_history_index",
        all_tenants?: true
      )

      index([:tenant_id, :operation_id],
        name: "platform_temporal_qualification_fact_operation_index",
        all_tenants?: true
      )

      index([:tenant_id, :reverses_fact_id],
        name: "platform_temporal_qualification_fact_reversal_index",
        unique: true,
        where: "kind = 'reversal'",
        all_tenants?: true
      )
    end

    references do
      reference(:reversed_fact,
        name: "platform_temporal_fact_reversal_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :simple
      )
    end

    check_constraints do
      check_constraint([:kind, :reverses_fact_id], "platform_temporal_fact_kind_shape",
        check: """
        (kind = 'entry' AND reverses_fact_id IS NULL) OR
        (kind = 'reversal' AND reverses_fact_id IS NOT NULL)
        """
      )

      check_constraint(:quantity, "platform_temporal_fact_quantity_nonzero",
        check: "quantity <> 0"
      )
    end

    custom_statements do
      statement :platform_temporal_qualification_fact_guard_function do
        global? true
        after_tables(["platform_temporal_qualification_facts"])

        up("""
        CREATE FUNCTION guard_platform_temporal_qualification_fact()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $$
        BEGIN
          IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION USING
              ERRCODE = '23514',
              CONSTRAINT = 'platform_temporal_qualification_fact_delete_forbidden',
              MESSAGE = 'temporal qualification fact deletion is forbidden';
          END IF;

          IF TG_OP = 'UPDATE' THEN
            RAISE EXCEPTION USING
              ERRCODE = '23514',
              CONSTRAINT = 'platform_temporal_qualification_fact_immutable',
              MESSAGE = 'temporal qualification facts are immutable';
          END IF;

          NEW.recorded_at := transaction_timestamp() AT TIME ZONE 'UTC';

          IF NEW.kind = 'reversal' AND NOT EXISTS (
            SELECT 1
            FROM platform_temporal_qualification_facts
            WHERE id = NEW.reverses_fact_id
              AND tenant_id = NEW.tenant_id
              AND scope_id = NEW.scope_id
              AND kind = 'entry'
          ) THEN
            RAISE EXCEPTION USING
              ERRCODE = '23514',
              CONSTRAINT = 'platform_temporal_qualification_fact_reversal_target',
              MESSAGE = 'temporal qualification reversal target is invalid';
          END IF;

          RETURN NEW;
        END;
        $$;
        """)

        down("DROP FUNCTION guard_platform_temporal_qualification_fact();")
      end

      statement :platform_temporal_qualification_fact_guard_trigger do
        global? true
        after_tables(["platform_temporal_qualification_facts"])

        up("""
        CREATE TRIGGER platform_temporal_qualification_fact_guard
        BEFORE INSERT OR UPDATE OR DELETE
        ON platform_temporal_qualification_facts
        FOR EACH ROW
        EXECUTE FUNCTION guard_platform_temporal_qualification_fact();
        """)

        down("""
        DROP TRIGGER platform_temporal_qualification_fact_guard
          ON platform_temporal_qualification_facts;
        """)
      end
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  relationships do
    belongs_to :reversed_fact, __MODULE__ do
      source_attribute :reverses_fact_id
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

    attribute :scope_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :operation_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :kind, :atom do
      allow_nil? false
      public? false
      constraints one_of: [:entry, :reversal]
    end

    attribute :reverses_fact_id, :uuid do
      allow_nil? true
      public? false
    end

    attribute :effective_on, :date do
      allow_nil? false
      public? false
    end

    attribute :quantity, :integer do
      allow_nil? false
      public? false
    end

    attribute :recorded_at, :utc_datetime_usec do
      allow_nil? false
      public? false
    end
  end
end
