defmodule Chimwemwe.Platform.TemporalQualification.Revision do
  @moduledoc """
  Immutable recorded revision for the neutral ADR 0018 qualification aggregate.

  Revisions are serialized per tenant and aggregate, receive writer time from
  PostgreSQL, and form one unbranched consecutive predecessor chain.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_temporal_qualification_revisions"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_temporal_qualification_revisions_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:id, :tenant_id, :aggregate_id],
        name: "platform_temporal_qualification_revisions_aggregate_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :aggregate_id, :aggregate_revision],
        name: "platform_temporal_qualification_revision_number_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :operation_id],
        name: "platform_temporal_qualification_revision_operation_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :aggregate_id, :recorded_at, :id],
        name: "platform_temporal_qualification_revision_history_index",
        all_tenants?: true
      )
    end

    references do
      reference(:aggregate,
        name: "platform_temporal_revision_aggregate_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:predecessor,
        name: "platform_temporal_revision_predecessor_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :simple
      )
    end

    check_constraints do
      check_constraint(
        [:aggregate_revision, :predecessor_revision_id],
        "platform_temporal_revision_predecessor_shape",
        check: """
        (aggregate_revision = 1 AND predecessor_revision_id IS NULL) OR
        (aggregate_revision > 1 AND predecessor_revision_id IS NOT NULL)
        """
      )

      check_constraint(:aggregate_revision, "platform_temporal_revision_number_positive",
        check: "aggregate_revision >= 1"
      )

      check_constraint(:reason_code, "platform_temporal_revision_reason_not_empty",
        check: "char_length(reason_code) BETWEEN 1 AND 80"
      )
    end

    custom_statements do
      statement :platform_temporal_qualification_revision_guard_function do
        global? true
        after_tables(["platform_temporal_qualification_revisions"])

        up("""
        CREATE FUNCTION guard_platform_temporal_qualification_revision()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $$
        BEGIN
          IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION USING
              ERRCODE = '23514',
              CONSTRAINT = 'platform_temporal_qualification_revision_delete_forbidden',
              MESSAGE = 'temporal qualification revision deletion is forbidden';
          END IF;

          IF TG_OP = 'UPDATE' THEN
            RAISE EXCEPTION USING
              ERRCODE = '23514',
              CONSTRAINT = 'platform_temporal_qualification_revision_immutable',
              MESSAGE = 'temporal qualification revisions are immutable';
          END IF;

          PERFORM pg_advisory_xact_lock(
            hashtextextended(
              'platform-temporal-qualification-revision:' ||
                NEW.tenant_id::text || ':' || NEW.aggregate_id::text,
              0
            )
          );

          NEW.recorded_at := transaction_timestamp() AT TIME ZONE 'UTC';

          IF NEW.aggregate_revision = 1 THEN
            IF EXISTS (
              SELECT 1
              FROM platform_temporal_qualification_revisions
              WHERE tenant_id = NEW.tenant_id
                AND aggregate_id = NEW.aggregate_id
            ) THEN
              RAISE EXCEPTION USING
                ERRCODE = '23514',
                CONSTRAINT = 'platform_temporal_qualification_revision_chain',
                MESSAGE = 'temporal qualification baseline revision already exists';
            END IF;
          ELSIF NOT EXISTS (
            SELECT 1
            FROM platform_temporal_qualification_revisions
            WHERE id = NEW.predecessor_revision_id
              AND tenant_id = NEW.tenant_id
              AND aggregate_id = NEW.aggregate_id
              AND aggregate_revision = NEW.aggregate_revision - 1
          ) THEN
            RAISE EXCEPTION USING
              ERRCODE = '23514',
              CONSTRAINT = 'platform_temporal_qualification_revision_chain',
              MESSAGE = 'temporal qualification predecessor is not consecutive';
          END IF;

          RETURN NEW;
        END;
        $$;
        """)

        down("DROP FUNCTION guard_platform_temporal_qualification_revision();")
      end

      statement :platform_temporal_qualification_revision_guard_trigger do
        global? true
        after_tables(["platform_temporal_qualification_revisions"])

        up("""
        CREATE TRIGGER platform_temporal_qualification_revision_guard
        BEFORE INSERT OR UPDATE OR DELETE
        ON platform_temporal_qualification_revisions
        FOR EACH ROW
        EXECUTE FUNCTION guard_platform_temporal_qualification_revision();
        """)

        down("""
        DROP TRIGGER platform_temporal_qualification_revision_guard
          ON platform_temporal_qualification_revisions;
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
    belongs_to :aggregate, Chimwemwe.Platform.TemporalQualification.Aggregate do
      source_attribute :aggregate_id
      destination_attribute :id
      define_attribute? false
      public? false
    end

    belongs_to :predecessor, __MODULE__ do
      source_attribute :predecessor_revision_id
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

    attribute :aggregate_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :operation_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :aggregate_revision, :integer do
      allow_nil? false
      public? false
      constraints min: 1
    end

    attribute :predecessor_revision_id, :uuid do
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
