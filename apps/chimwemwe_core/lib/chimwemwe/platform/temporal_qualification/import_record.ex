defmodule Chimwemwe.Platform.TemporalQualification.ImportRecord do
  @moduledoc """
  Immutable provenance version for one neutral baseline import or reconciliation.

  Source identifiers are stored only as caller-computed SHA-256 digests. A
  conflict version has no target; reconciliation appends a target-bearing
  successor instead of mutating or fabricating source history.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_temporal_qualification_import_records"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_temporal_import_records_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :import_id, :version],
        name: "platform_temporal_import_records_version_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :source_snapshot_digest, :source_identifier_digest, :mapping_revision],
        name: "platform_temporal_import_records_source_index",
        unique: true,
        where: "version = 1",
        all_tenants?: true
      )

      index([:tenant_id, :predecessor_record_id],
        name: "platform_temporal_import_records_successor_index",
        unique: true,
        where: "predecessor_record_id IS NOT NULL",
        all_tenants?: true
      )
    end

    check_constraints do
      check_constraint(
        [:source_snapshot_digest, :source_identifier_digest],
        "platform_temporal_import_digest_shape",
        check:
          "octet_length(source_snapshot_digest) = 32 AND octet_length(source_identifier_digest) = 32"
      )

      check_constraint(:mapping_revision, "platform_temporal_import_mapping_revision_shape",
        check:
          "char_length(mapping_revision) BETWEEN 1 AND 80 AND mapping_revision ~ '^[A-Za-z0-9][A-Za-z0-9._-]*$'"
      )

      check_constraint(
        [:state, :conflict_code, :aggregate_id, :revision_id, :predecessor_record_id, :version],
        "platform_temporal_import_state_shape",
        check: """
        (state = 'baseline' AND conflict_code IS NULL AND aggregate_id IS NOT NULL AND revision_id IS NOT NULL AND predecessor_record_id IS NULL AND version = 1) OR
        (state = 'reconciliation_required' AND conflict_code IS NOT NULL AND aggregate_id IS NULL AND revision_id IS NULL AND predecessor_record_id IS NULL AND version = 1) OR
        (state = 'reconciled' AND conflict_code IS NULL AND aggregate_id IS NOT NULL AND revision_id IS NOT NULL AND predecessor_record_id IS NOT NULL AND version = 2)
        """
      )
    end

    custom_statements do
      statement :platform_temporal_import_record_guard_function do
        global? true

        after_tables([
          "platform_temporal_qualification_import_records",
          "platform_temporal_qualification_revisions"
        ])

        up("""
        CREATE FUNCTION guard_platform_temporal_import_record()
        RETURNS trigger LANGUAGE plpgsql AS $$
        DECLARE
          predecessor_state text;
          predecessor_import uuid;
        BEGIN
          IF TG_OP IN ('UPDATE', 'DELETE') THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
              CONSTRAINT = 'platform_temporal_import_record_immutable',
              MESSAGE = 'temporal import provenance is immutable';
          END IF;

          NEW.recorded_at := transaction_timestamp() AT TIME ZONE 'UTC';

          IF NEW.aggregate_id IS NOT NULL AND NOT EXISTS (
            SELECT 1 FROM platform_temporal_qualification_revisions
            WHERE tenant_id = NEW.tenant_id AND aggregate_id = NEW.aggregate_id AND id = NEW.revision_id
          ) THEN
            RAISE EXCEPTION USING ERRCODE = '23503',
              CONSTRAINT = 'platform_temporal_import_target_missing',
              MESSAGE = 'temporal import target revision is missing';
          END IF;

          IF NEW.predecessor_record_id IS NOT NULL THEN
            SELECT state, import_id INTO predecessor_state, predecessor_import
            FROM platform_temporal_qualification_import_records
            WHERE tenant_id = NEW.tenant_id AND id = NEW.predecessor_record_id;

            IF predecessor_state IS DISTINCT FROM 'reconciliation_required'
               OR predecessor_import IS DISTINCT FROM NEW.import_id THEN
              RAISE EXCEPTION USING ERRCODE = '23514',
                CONSTRAINT = 'platform_temporal_import_predecessor_invalid',
                MESSAGE = 'temporal import reconciliation predecessor is invalid';
            END IF;
          END IF;

          RETURN NEW;
        END;
        $$;
        """)

        down("DROP FUNCTION guard_platform_temporal_import_record();")
      end

      statement :platform_temporal_import_record_guard_trigger do
        global? true
        after_tables(["platform_temporal_qualification_import_records"])

        up("""
        CREATE TRIGGER platform_temporal_import_record_guard
        BEFORE INSERT OR UPDATE OR DELETE ON platform_temporal_qualification_import_records
        FOR EACH ROW EXECUTE FUNCTION guard_platform_temporal_import_record();
        """)

        down(
          "DROP TRIGGER platform_temporal_import_record_guard ON platform_temporal_qualification_import_records;"
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
    action :register_baseline, :struct do
      public? false
      transaction? true
      constraints instance_of: Chimwemwe.Platform.TemporalQualification.ImportResult
      argument :import_id, :uuid, allow_nil?: false
      argument :module_key, :string, allow_nil?: false
      argument :source_snapshot_digest, :binary, allow_nil?: false
      argument :source_identifier_digest, :binary, allow_nil?: false
      argument :mapping_revision, :string, allow_nil?: false
      argument :aggregate_id, :uuid, allow_nil?: false
      argument :revision_id, :uuid, allow_nil?: false
      argument :reason_code, :string, allow_nil?: false
      argument :idempotency_key, :uuid, allow_nil?: false
      argument :causation_id, :uuid, allow_nil?: false
      run Chimwemwe.Platform.TemporalQualification.RegisterBaselineImport
    end

    action :register_conflict, :struct do
      public? false
      transaction? true
      constraints instance_of: Chimwemwe.Platform.TemporalQualification.ImportResult
      argument :import_id, :uuid, allow_nil?: false
      argument :module_key, :string, allow_nil?: false
      argument :source_snapshot_digest, :binary, allow_nil?: false
      argument :source_identifier_digest, :binary, allow_nil?: false
      argument :mapping_revision, :string, allow_nil?: false
      argument :conflict_code, :string, allow_nil?: false
      argument :reason_code, :string, allow_nil?: false
      argument :idempotency_key, :uuid, allow_nil?: false
      argument :causation_id, :uuid, allow_nil?: false
      run Chimwemwe.Platform.TemporalQualification.RegisterImportConflict
    end

    action :reconcile_conflict, :struct do
      public? false
      transaction? true
      constraints instance_of: Chimwemwe.Platform.TemporalQualification.ImportResult
      argument :import_id, :uuid, allow_nil?: false
      argument :expected_record_id, :uuid, allow_nil?: false
      argument :module_key, :string, allow_nil?: false
      argument :aggregate_id, :uuid, allow_nil?: false
      argument :revision_id, :uuid, allow_nil?: false
      argument :reason_code, :string, allow_nil?: false
      argument :idempotency_key, :uuid, allow_nil?: false
      argument :causation_id, :uuid, allow_nil?: false
      run Chimwemwe.Platform.TemporalQualification.ReconcileImportConflict
    end
  end

  policies do
    policy action([:register_baseline, :register_conflict]) do
      forbid_unless actor_present()

      authorize_if {Chimwemwe.Platform.Policy.HasCapability,
                    capability: "platform.temporal_qualification.import.register"}
    end

    policy action(:reconcile_conflict) do
      forbid_unless actor_present()

      authorize_if {Chimwemwe.Platform.Policy.HasCapability,
                    capability: "platform.temporal_qualification.import.reconcile"}
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :tenant_id, :uuid, allow_nil?: false, public?: false
    attribute :import_id, :uuid, allow_nil?: false, public?: false
    attribute :version, :integer, allow_nil?: false, public?: false, constraints: [min: 1, max: 2]
    attribute :predecessor_record_id, :uuid, allow_nil?: true, public?: false
    attribute :module_key, :string, allow_nil?: false, public?: false

    attribute :state, :atom,
      allow_nil?: false,
      public?: false,
      constraints: [one_of: [:baseline, :reconciliation_required, :reconciled]]

    attribute :conflict_code, :string, allow_nil?: true, public?: false
    attribute :source_snapshot_digest, :binary, allow_nil?: false, public?: false
    attribute :source_identifier_digest, :binary, allow_nil?: false, public?: false
    attribute :mapping_revision, :string, allow_nil?: false, public?: false
    attribute :aggregate_id, :uuid, allow_nil?: true, public?: false
    attribute :revision_id, :uuid, allow_nil?: true, public?: false
    attribute :recorded_at, :utc_datetime_usec, allow_nil?: false, public?: false
  end
end
