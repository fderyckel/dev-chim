defmodule Chimwemwe.Platform.TemporalQualification.RetentionReceipt do
  @moduledoc "Immutable, content-minimized retention and erasure receipt."

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_temporal_qualification_retention_receipts"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_temporal_retention_receipts_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :control_id, :version],
        name: "platform_temporal_retention_receipts_version_index",
        unique: true,
        all_tenants?: true
      )
    end

    check_constraints do
      check_constraint(:reason_code, "platform_temporal_retention_receipt_reason_shape",
        check:
          "char_length(reason_code) BETWEEN 1 AND 80 AND reason_code ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)*$'"
      )

      check_constraint(
        [:operation, :hold_reference_digest],
        "platform_temporal_retention_receipt_operation_shape",
        check: """
        (operation IN ('declared', 'erased') AND hold_reference_digest IS NULL) OR
        (operation IN ('hold_placed', 'hold_released') AND octet_length(hold_reference_digest) = 32)
        """
      )
    end

    custom_statements do
      statement :platform_temporal_retention_receipt_guard_function do
        global? true
        after_tables(["platform_temporal_qualification_retention_receipts"])

        up("""
        CREATE FUNCTION guard_platform_temporal_retention_receipt()
        RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN
          IF TG_OP IN ('UPDATE', 'DELETE') THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
              CONSTRAINT = 'platform_temporal_retention_receipt_immutable',
              MESSAGE = 'temporal retention receipts are immutable';
          END IF;
          NEW.recorded_at := transaction_timestamp() AT TIME ZONE 'UTC';
          RETURN NEW;
        END;
        $$;
        """)

        down("DROP FUNCTION guard_platform_temporal_retention_receipt();")
      end

      statement :platform_temporal_retention_receipt_guard_trigger do
        global? true
        after_tables(["platform_temporal_qualification_retention_receipts"])

        up("""
        CREATE TRIGGER platform_temporal_retention_receipt_guard
        BEFORE INSERT OR UPDATE OR DELETE ON platform_temporal_qualification_retention_receipts
        FOR EACH ROW EXECUTE FUNCTION guard_platform_temporal_retention_receipt();
        """)

        down(
          "DROP TRIGGER platform_temporal_retention_receipt_guard ON platform_temporal_qualification_retention_receipts;"
        )
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
    attribute :tenant_id, :uuid, allow_nil?: false, public?: false
    attribute :control_id, :uuid, allow_nil?: false, public?: false
    attribute :aggregate_id, :uuid, allow_nil?: false, public?: false
    attribute :scope_id, :uuid, allow_nil?: false, public?: false

    attribute :operation, :atom,
      allow_nil?: false,
      public?: false,
      constraints: [one_of: [:declared, :hold_placed, :hold_released, :erased]]

    attribute :version, :integer, allow_nil?: false, public?: false, constraints: [min: 1]
    attribute :reason_code, :string, allow_nil?: false, public?: false
    attribute :hold_reference_digest, :binary, allow_nil?: true, public?: false

    attribute :redacted_segment_count, :integer,
      allow_nil?: false,
      public?: false,
      default: 0,
      constraints: [min: 0]

    attribute :redacted_fact_count, :integer,
      allow_nil?: false,
      public?: false,
      default: 0,
      constraints: [min: 0]

    attribute :purged_projection_count, :integer,
      allow_nil?: false,
      public?: false,
      default: 0,
      constraints: [min: 0]

    attribute :recorded_at, :utc_datetime_usec, allow_nil?: false, public?: false
  end
end
