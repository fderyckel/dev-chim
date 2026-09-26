defmodule Chimwemwe.Platform.TemporalQualification.FactOperation do
  @moduledoc """
  Immutable operation identity and correction reason for the neutral fact proof.

  Facts carry this identity, while this record preserves operation-level meaning.
  It is qualification-only and exposes no direct action surface.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_temporal_qualification_fact_operations"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_temporal_fact_operations_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:id, :tenant_id, :scope_id],
        name: "platform_temporal_fact_operations_scope_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :scope_id, :recorded_at, :id],
        name: "platform_temporal_fact_operations_history_index",
        all_tenants?: true
      )

      index([:tenant_id, :target_fact_id],
        name: "platform_temporal_fact_operations_target_index",
        unique: true,
        where: "kind = 'reverse_and_replace'",
        all_tenants?: true
      )
    end

    check_constraints do
      check_constraint([:kind, :target_fact_id], "platform_temporal_fact_operation_kind_shape",
        check: """
        (kind = 'record' AND target_fact_id IS NULL) OR
        (kind = 'reverse_and_replace' AND target_fact_id IS NOT NULL)
        """
      )

      check_constraint(:reason_code, "platform_temporal_fact_operation_reason_shape",
        check: """
        char_length(reason_code) BETWEEN 1 AND 80 AND
        reason_code ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)*$'
        """
      )
    end

    custom_statements do
      statement :platform_temporal_fact_operation_guard_function do
        global? true

        after_tables([
          "platform_temporal_qualification_fact_operations",
          "platform_temporal_qualification_facts"
        ])

        up("""
        CREATE FUNCTION guard_platform_temporal_fact_operation()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $$
        BEGIN
          IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION USING
              ERRCODE = '23514',
              CONSTRAINT = 'platform_temporal_fact_operation_delete_forbidden',
              MESSAGE = 'temporal qualification fact operation deletion is forbidden';
          END IF;

          IF TG_OP = 'UPDATE' THEN
            RAISE EXCEPTION USING
              ERRCODE = '23514',
              CONSTRAINT = 'platform_temporal_fact_operation_immutable',
              MESSAGE = 'temporal qualification fact operations are immutable';
          END IF;

          NEW.recorded_at := transaction_timestamp() AT TIME ZONE 'UTC';

          IF NEW.kind = 'reverse_and_replace' AND NOT EXISTS (
            SELECT 1
            FROM platform_temporal_qualification_facts
            WHERE id = NEW.target_fact_id
              AND tenant_id = NEW.tenant_id
              AND scope_id = NEW.scope_id
              AND kind = 'entry'
          ) THEN
            RAISE EXCEPTION USING
              ERRCODE = '23514',
              CONSTRAINT = 'platform_temporal_fact_operation_target',
              MESSAGE = 'temporal qualification correction target is invalid';
          END IF;

          RETURN NEW;
        END;
        $$;
        """)

        down("DROP FUNCTION guard_platform_temporal_fact_operation();")
      end

      statement :platform_temporal_fact_operation_guard_trigger do
        global? true
        after_tables(["platform_temporal_qualification_fact_operations"])

        up("""
        CREATE TRIGGER platform_temporal_fact_operation_guard
        BEFORE INSERT OR UPDATE OR DELETE
        ON platform_temporal_qualification_fact_operations
        FOR EACH ROW
        EXECUTE FUNCTION guard_platform_temporal_fact_operation();
        """)

        down("""
        DROP TRIGGER platform_temporal_fact_operation_guard
          ON platform_temporal_qualification_fact_operations;
        """)
      end
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
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

    attribute :kind, :atom do
      allow_nil? false
      public? false
      constraints one_of: [:record, :reverse_and_replace]
    end

    attribute :target_fact_id, :uuid do
      allow_nil? true
      public? false
    end

    attribute :reason_code, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 80
    end

    attribute :recorded_at, :utc_datetime_usec do
      allow_nil? false
      public? false
    end
  end
end
