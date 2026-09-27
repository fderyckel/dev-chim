defmodule Chimwemwe.Platform.TemporalQualification.RetentionControl do
  @moduledoc """
  Current retention, legal-hold, and erasure selector for one neutral scope.

  Receipts preserve lifecycle history; this row contains only the current
  fail-closed selector. The boundary is qualification-only and does not define
  a real domain retention schedule.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_temporal_qualification_retention_controls"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_temporal_retention_controls_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :aggregate_id],
        name: "platform_temporal_retention_controls_aggregate_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :module_key, :state],
        name: "platform_temporal_retention_controls_module_state_index",
        all_tenants?: true
      )
    end

    check_constraints do
      check_constraint(:module_key, "platform_temporal_retention_module_key_shape",
        check: """
        char_length(module_key) BETWEEN 3 AND 120 AND
        module_key ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$'
        """
      )

      check_constraint(:policy_key, "platform_temporal_retention_policy_key_shape",
        check: """
        char_length(policy_key) BETWEEN 3 AND 120 AND
        policy_key ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$'
        """
      )

      check_constraint(
        [:retention_started_on, :retain_until],
        "platform_temporal_retention_window_valid",
        check: "retention_started_on <= retain_until"
      )

      check_constraint(
        [:state, :active_hold_digest, :erased_at],
        "platform_temporal_retention_state_shape",
        check: """
        (state = 'retained' AND active_hold_digest IS NULL AND erased_at IS NULL) OR
        (state = 'held' AND octet_length(active_hold_digest) = 32 AND erased_at IS NULL) OR
        (state = 'erased' AND active_hold_digest IS NULL AND erased_at IS NOT NULL)
        """
      )
    end

    custom_statements do
      statement :platform_temporal_retention_control_guard_function do
        global? true

        after_tables([
          "platform_temporal_qualification_retention_controls",
          "platform_temporal_qualification_retention_receipts"
        ])

        up("""
        CREATE FUNCTION guard_platform_temporal_retention_control()
        RETURNS trigger LANGUAGE plpgsql AS $$
        DECLARE
          receipt_operation text;
          receipt_version bigint;
          receipt_hold_digest bytea;
        BEGIN
          IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
              CONSTRAINT = 'platform_temporal_retention_control_delete_forbidden',
              MESSAGE = 'temporal retention control deletion is forbidden';
          END IF;

          IF TG_OP = 'UPDATE' THEN
            IF NEW.id <> OLD.id
               OR NEW.tenant_id <> OLD.tenant_id
               OR NEW.aggregate_id <> OLD.aggregate_id
               OR NEW.scope_id <> OLD.scope_id
               OR NEW.module_key <> OLD.module_key
               OR NEW.policy_key <> OLD.policy_key
               OR NEW.classification <> OLD.classification
               OR NEW.retention_started_on <> OLD.retention_started_on
               OR NEW.retain_until <> OLD.retain_until
               OR NEW.inserted_at <> OLD.inserted_at
               OR NEW.version <> OLD.version + 1 THEN
              RAISE EXCEPTION USING ERRCODE = '23514',
                CONSTRAINT = 'platform_temporal_retention_control_transition_invalid',
                MESSAGE = 'temporal retention control transition is invalid';
            END IF;

            SELECT operation, version, hold_reference_digest
            INTO receipt_operation, receipt_version, receipt_hold_digest
            FROM platform_temporal_qualification_retention_receipts
            WHERE id = NEW.current_receipt_id
              AND tenant_id = NEW.tenant_id
              AND control_id = NEW.id
              AND aggregate_id = NEW.aggregate_id;

            IF receipt_version IS DISTINCT FROM NEW.version OR NOT (
              (OLD.state = 'retained' AND NEW.state = 'held'
                AND receipt_operation = 'hold_placed'
                AND NEW.active_hold_digest = receipt_hold_digest
                AND NEW.erased_at IS NULL)
              OR
              (OLD.state = 'held' AND NEW.state = 'retained'
                AND receipt_operation = 'hold_released'
                AND receipt_hold_digest = OLD.active_hold_digest
                AND NEW.active_hold_digest IS NULL
                AND NEW.erased_at IS NULL)
              OR
              (OLD.state = 'retained' AND NEW.state = 'erased'
                AND receipt_operation = 'erased'
                AND NEW.active_hold_digest IS NULL
                AND NEW.retain_until <= CURRENT_DATE
                AND NEW.erased_at IS NOT NULL)
            ) THEN
              RAISE EXCEPTION USING ERRCODE = '23514',
                CONSTRAINT = 'platform_temporal_retention_control_transition_invalid',
                MESSAGE = 'temporal retention control transition is invalid';
            END IF;

            NEW.updated_at := transaction_timestamp() AT TIME ZONE 'UTC';
          END IF;

          RETURN NEW;
        END;
        $$;
        """)

        down("DROP FUNCTION guard_platform_temporal_retention_control();")
      end

      statement :platform_temporal_retention_control_guard_trigger do
        global? true

        after_tables([
          "platform_temporal_qualification_retention_controls",
          "platform_temporal_qualification_retention_receipts"
        ])

        up("""
        CREATE TRIGGER platform_temporal_retention_control_guard
        BEFORE UPDATE OR DELETE ON platform_temporal_qualification_retention_controls
        FOR EACH ROW EXECUTE FUNCTION guard_platform_temporal_retention_control();
        """)

        down(
          "DROP TRIGGER platform_temporal_retention_control_guard ON platform_temporal_qualification_retention_controls;"
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
    action :declare_retention, :struct do
      public? false
      transaction? true
      constraints instance_of: Chimwemwe.Platform.TemporalQualification.RetentionResult

      argument :aggregate_id, :uuid, allow_nil?: false
      argument :module_key, :string, allow_nil?: false
      argument :policy_key, :string, allow_nil?: false

      argument :classification, :atom,
        allow_nil?: false,
        constraints: [one_of: [:internal, :restricted]]

      argument :retention_started_on, :date, allow_nil?: false
      argument :retain_until, :date, allow_nil?: false

      argument :reason_code, :string,
        allow_nil?: false,
        constraints: [min_length: 1, max_length: 80, trim?: true]

      argument :idempotency_key, :uuid, allow_nil?: false
      argument :causation_id, :uuid, allow_nil?: false

      run Chimwemwe.Platform.TemporalQualification.DeclareRetention
    end

    action :place_legal_hold, :struct do
      public? false
      transaction? true
      constraints instance_of: Chimwemwe.Platform.TemporalQualification.RetentionResult

      argument :control_id, :uuid, allow_nil?: false
      argument :expected_version, :integer, allow_nil?: false, constraints: [min: 1]
      argument :hold_reference_digest, :binary, allow_nil?: false

      argument :reason_code, :string,
        allow_nil?: false,
        constraints: [min_length: 1, max_length: 80, trim?: true]

      argument :idempotency_key, :uuid, allow_nil?: false
      argument :causation_id, :uuid, allow_nil?: false

      run Chimwemwe.Platform.TemporalQualification.PlaceLegalHold
    end

    action :release_legal_hold, :struct do
      public? false
      transaction? true
      constraints instance_of: Chimwemwe.Platform.TemporalQualification.RetentionResult

      argument :control_id, :uuid, allow_nil?: false
      argument :expected_version, :integer, allow_nil?: false, constraints: [min: 1]
      argument :hold_reference_digest, :binary, allow_nil?: false

      argument :reason_code, :string,
        allow_nil?: false,
        constraints: [min_length: 1, max_length: 80, trim?: true]

      argument :idempotency_key, :uuid, allow_nil?: false
      argument :causation_id, :uuid, allow_nil?: false

      run Chimwemwe.Platform.TemporalQualification.ReleaseLegalHold
    end

    action :erase_retained_content, :struct do
      public? false
      transaction? true
      constraints instance_of: Chimwemwe.Platform.TemporalQualification.RetentionResult

      argument :control_id, :uuid, allow_nil?: false
      argument :expected_version, :integer, allow_nil?: false, constraints: [min: 1]

      argument :reason_code, :string,
        allow_nil?: false,
        constraints: [min_length: 1, max_length: 80, trim?: true]

      argument :idempotency_key, :uuid, allow_nil?: false
      argument :causation_id, :uuid, allow_nil?: false

      run Chimwemwe.Platform.TemporalQualification.EraseRetainedContent
    end
  end

  policies do
    policy action(:declare_retention) do
      forbid_unless actor_present()

      authorize_if {Chimwemwe.Platform.Policy.HasCapability,
                    capability: "platform.temporal_qualification.retention.declare"}
    end

    policy action(:place_legal_hold) do
      forbid_unless actor_present()

      authorize_if {Chimwemwe.Platform.Policy.HasCapability,
                    capability: "platform.temporal_qualification.legal_hold.place"}
    end

    policy action(:release_legal_hold) do
      forbid_unless actor_present()

      authorize_if {Chimwemwe.Platform.Policy.HasCapability,
                    capability: "platform.temporal_qualification.legal_hold.release"}
    end

    policy action(:erase_retained_content) do
      forbid_unless actor_present()

      authorize_if {Chimwemwe.Platform.Policy.HasCapability,
                    capability: "platform.temporal_qualification.retention.erase"}
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :tenant_id, :uuid, allow_nil?: false, public?: false
    attribute :aggregate_id, :uuid, allow_nil?: false, public?: false
    attribute :scope_id, :uuid, allow_nil?: false, public?: false
    attribute :module_key, :string, allow_nil?: false, public?: false
    attribute :policy_key, :string, allow_nil?: false, public?: false

    attribute :classification, :atom,
      allow_nil?: false,
      public?: false,
      constraints: [one_of: [:internal, :restricted]]

    attribute :retention_started_on, :date, allow_nil?: false, public?: false
    attribute :retain_until, :date, allow_nil?: false, public?: false

    attribute :state, :atom,
      allow_nil?: false,
      public?: false,
      constraints: [one_of: [:retained, :held, :erased]]

    attribute :version, :integer, allow_nil?: false, public?: false, constraints: [min: 1]
    attribute :active_hold_digest, :binary, allow_nil?: true, public?: false
    attribute :current_receipt_id, :uuid, allow_nil?: false, public?: false
    attribute :erased_at, :utc_datetime_usec, allow_nil?: true, public?: false
    create_timestamp :inserted_at, public?: false
    update_timestamp :updated_at, public?: false
  end
end
