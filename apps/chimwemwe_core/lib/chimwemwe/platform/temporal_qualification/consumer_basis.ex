defmodule Chimwemwe.Platform.TemporalQualification.ConsumerBasis do
  @moduledoc """
  Immutable exact-revision basis for one neutral deliberate-reconciliation consumer.

  Reconciliation appends a successor basis. It never rewrites what the consumer
  previously used and it cannot be driven directly by an outbox payload.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_temporal_qualification_consumer_bases"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_temporal_consumer_bases_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:id, :tenant_id, :consumer_id, :aggregate_id],
        name: "platform_temporal_consumer_bases_chain_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :consumer_id, :basis_version],
        name: "platform_temporal_consumer_bases_version_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :consumer_id, :recorded_at, :id],
        name: "platform_temporal_consumer_bases_history_index",
        all_tenants?: true
      )

      index([:tenant_id, :predecessor_basis_id],
        name: "platform_temporal_consumer_bases_successor_index",
        unique: true,
        where: "predecessor_basis_id IS NOT NULL",
        all_tenants?: true
      )
    end

    references do
      reference(:source_revision,
        name: "platform_temporal_consumer_basis_revision_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:predecessor_basis,
        name: "platform_temporal_consumer_basis_predecessor_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :simple
      )
    end

    check_constraints do
      check_constraint(
        [:basis_version, :predecessor_basis_id],
        "platform_temporal_consumer_basis_chain_shape",
        check: """
        (basis_version = 1 AND predecessor_basis_id IS NULL) OR
        (basis_version > 1 AND predecessor_basis_id IS NOT NULL)
        """
      )

      check_constraint(:reason_code, "platform_temporal_consumer_basis_reason_shape",
        check: """
        char_length(reason_code) BETWEEN 1 AND 80 AND
        reason_code ~ '^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)*$'
        """
      )
    end

    custom_statements do
      statement :platform_temporal_consumer_basis_guard_function do
        global? true

        after_tables([
          "platform_temporal_qualification_aggregates",
          "platform_temporal_qualification_consumer_bases",
          "platform_temporal_qualification_revisions"
        ])

        up("""
        CREATE FUNCTION guard_platform_temporal_consumer_basis()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $$
        DECLARE
          prior_version bigint;
        BEGIN
          IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION USING
              ERRCODE = '23514',
              CONSTRAINT = 'platform_temporal_consumer_basis_delete_forbidden',
              MESSAGE = 'temporal qualification consumer basis deletion is forbidden';
          END IF;

          IF TG_OP = 'UPDATE' THEN
            RAISE EXCEPTION USING
              ERRCODE = '23514',
              CONSTRAINT = 'platform_temporal_consumer_basis_immutable',
              MESSAGE = 'temporal qualification consumer bases are immutable';
          END IF;

          NEW.recorded_at := transaction_timestamp() AT TIME ZONE 'UTC';

          IF NOT EXISTS (
            SELECT 1
            FROM platform_temporal_qualification_aggregates AS aggregate
            JOIN platform_temporal_qualification_revisions AS revision
              ON revision.tenant_id = aggregate.tenant_id
             AND revision.aggregate_id = aggregate.id
             AND revision.id = aggregate.current_revision_id
            WHERE aggregate.tenant_id = NEW.tenant_id
              AND aggregate.id = NEW.aggregate_id
              AND revision.id = NEW.revision_id
          ) THEN
            RAISE EXCEPTION USING
              ERRCODE = '23514',
              CONSTRAINT = 'platform_temporal_consumer_basis_current_revision',
              MESSAGE = 'consumer basis must reference the exact current source revision';
          END IF;

          IF NEW.basis_version > 1 THEN
            SELECT basis_version
            INTO prior_version
            FROM platform_temporal_qualification_consumer_bases
            WHERE id = NEW.predecessor_basis_id
              AND tenant_id = NEW.tenant_id
              AND consumer_id = NEW.consumer_id
              AND aggregate_id = NEW.aggregate_id;

            IF prior_version IS NULL OR NEW.basis_version <> prior_version + 1 THEN
              RAISE EXCEPTION USING
                ERRCODE = '23514',
                CONSTRAINT = 'platform_temporal_consumer_basis_predecessor',
                MESSAGE = 'consumer basis predecessor must be consecutive';
            END IF;
          END IF;

          RETURN NEW;
        END;
        $$;
        """)

        down("DROP FUNCTION guard_platform_temporal_consumer_basis();")
      end

      statement :platform_temporal_consumer_basis_guard_trigger do
        global? true
        after_tables(["platform_temporal_qualification_consumer_bases"])

        up("""
        CREATE TRIGGER platform_temporal_consumer_basis_guard
        BEFORE INSERT OR UPDATE OR DELETE
        ON platform_temporal_qualification_consumer_bases
        FOR EACH ROW
        EXECUTE FUNCTION guard_platform_temporal_consumer_basis();
        """)

        down("""
        DROP TRIGGER platform_temporal_consumer_basis_guard
          ON platform_temporal_qualification_consumer_bases;
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
    belongs_to :source_revision, Chimwemwe.Platform.TemporalQualification.Revision do
      source_attribute :revision_id
      destination_attribute :id
      define_attribute? false
      public? false
    end

    belongs_to :predecessor_basis, __MODULE__ do
      source_attribute :predecessor_basis_id
      destination_attribute :id
      define_attribute? false
      public? false
    end
  end

  actions do
    action :pin_revision, :struct do
      public? false
      transaction? true
      constraints instance_of: Chimwemwe.Platform.TemporalQualification.ConsumerResult

      argument :consumer_id, :uuid, allow_nil?: false
      argument :aggregate_id, :uuid, allow_nil?: false
      argument :revision_id, :uuid, allow_nil?: false

      argument :reason_code, :string do
        allow_nil? false
        constraints min_length: 1, max_length: 80, trim?: true
      end

      argument :idempotency_key, :uuid, allow_nil?: false
      argument :causation_id, :uuid, allow_nil?: false

      run Chimwemwe.Platform.TemporalQualification.PinConsumerRevision
    end

    action :reconcile_revision, :struct do
      public? false
      transaction? true
      constraints instance_of: Chimwemwe.Platform.TemporalQualification.ConsumerResult

      argument :consumer_id, :uuid, allow_nil?: false
      argument :expected_basis_id, :uuid, allow_nil?: false
      argument :target_revision_id, :uuid, allow_nil?: false

      argument :reason_code, :string do
        allow_nil? false
        constraints min_length: 1, max_length: 80, trim?: true
      end

      argument :idempotency_key, :uuid, allow_nil?: false
      argument :causation_id, :uuid, allow_nil?: false

      run Chimwemwe.Platform.TemporalQualification.ReconcileConsumerRevision
    end
  end

  policies do
    policy action(:pin_revision) do
      forbid_unless actor_present()

      authorize_if {Chimwemwe.Platform.Policy.HasCapability,
                    capability: "platform.temporal_qualification.consumers.pin"}
    end

    policy action(:reconcile_revision) do
      forbid_unless actor_present()

      authorize_if {Chimwemwe.Platform.Policy.HasCapability,
                    capability: "platform.temporal_qualification.consumers.reconcile"}
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :tenant_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :consumer_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :aggregate_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :revision_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :operation_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :basis_version, :integer do
      allow_nil? false
      public? false
      constraints min: 1
    end

    attribute :predecessor_basis_id, :uuid do
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
