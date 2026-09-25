defmodule Chimwemwe.Platform.TemporalQualification.Aggregate do
  @moduledoc """
  Stable identity and current-revision selector for the neutral ADR 0018 proof.

  This resource is qualification-only. It is not a reusable temporal library or
  a contract for a school business module. Its two private T1-B actions are
  reachable only through the trusted temporal-qualification boundary.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_temporal_qualification_aggregates"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_temporal_qualification_aggregates_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:id, :tenant_id, :scope_id],
        name: "platform_temporal_qualification_aggregates_scope_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :scope_id],
        name: "platform_temporal_qualification_scope_index",
        all_tenants?: true
      )
    end

    custom_statements do
      statement :platform_temporal_qualification_aggregate_guard_function do
        global? true
        after_tables(["platform_temporal_qualification_aggregates"])

        up("""
        CREATE FUNCTION guard_platform_temporal_qualification_aggregate()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $$
        DECLARE
          previous_revision bigint;
          selected_revision bigint;
        BEGIN
          IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION USING
              ERRCODE = '23514',
              CONSTRAINT = 'platform_temporal_qualification_aggregate_delete_forbidden',
              MESSAGE = 'temporal qualification aggregate deletion is forbidden';
          END IF;

          IF NEW.id <> OLD.id
             OR NEW.tenant_id <> OLD.tenant_id
             OR NEW.scope_id <> OLD.scope_id
             OR NEW.inserted_at <> OLD.inserted_at THEN
            RAISE EXCEPTION USING
              ERRCODE = '23514',
              CONSTRAINT = 'platform_temporal_qualification_aggregate_identity_immutable',
              MESSAGE = 'temporal qualification aggregate identity is immutable';
          END IF;

          IF OLD.current_revision_id IS NOT NULL
             AND NEW.current_revision_id IS NULL THEN
            RAISE EXCEPTION USING
              ERRCODE = '23514',
              CONSTRAINT = 'platform_temporal_qualification_current_revision_monotonic',
              MESSAGE = 'current temporal qualification revision cannot be cleared';
          END IF;

          IF OLD.current_revision_id IS DISTINCT FROM NEW.current_revision_id
             AND OLD.current_revision_id IS NOT NULL THEN
            SELECT aggregate_revision
            INTO previous_revision
            FROM platform_temporal_qualification_revisions
            WHERE id = OLD.current_revision_id
              AND tenant_id = OLD.tenant_id
              AND aggregate_id = OLD.id;

            SELECT aggregate_revision
            INTO selected_revision
            FROM platform_temporal_qualification_revisions
            WHERE id = NEW.current_revision_id
              AND tenant_id = NEW.tenant_id
              AND aggregate_id = NEW.id;

            IF selected_revision IS NULL OR selected_revision <= previous_revision THEN
              RAISE EXCEPTION USING
                ERRCODE = '23514',
                CONSTRAINT = 'platform_temporal_qualification_current_revision_monotonic',
                MESSAGE = 'current temporal qualification revision must advance';
            END IF;
          END IF;

          RETURN NEW;
        END;
        $$;
        """)

        down("DROP FUNCTION guard_platform_temporal_qualification_aggregate();")
      end

      statement :platform_temporal_qualification_aggregate_guard_trigger do
        global? true
        after_tables(["platform_temporal_qualification_aggregates"])

        up("""
        CREATE TRIGGER platform_temporal_qualification_aggregate_guard
        BEFORE UPDATE OR DELETE
        ON platform_temporal_qualification_aggregates
        FOR EACH ROW
        EXECUTE FUNCTION guard_platform_temporal_qualification_aggregate();
        """)

        down("""
        DROP TRIGGER platform_temporal_qualification_aggregate_guard
          ON platform_temporal_qualification_aggregates;
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
    action :publish_revision, :struct do
      public? false
      transaction? true
      constraints instance_of: Chimwemwe.Platform.TemporalQualification.RevisionResult

      argument :aggregate_id, :uuid do
        allow_nil? false
      end

      argument :scope_id, :uuid do
        allow_nil? false
      end

      argument :segments, {:array, :map} do
        allow_nil? false
        constraints min_length: 1, max_length: 32
      end

      argument :reason_code, :string do
        allow_nil? false
        constraints min_length: 1, max_length: 80, trim?: true
      end

      argument :idempotency_key, :uuid do
        allow_nil? false
      end

      argument :causation_id, :uuid do
        allow_nil? false
      end

      run Chimwemwe.Platform.TemporalQualification.PublishRevision
    end

    action :correct_revision, :struct do
      public? false
      transaction? true
      constraints instance_of: Chimwemwe.Platform.TemporalQualification.RevisionResult

      argument :aggregate_id, :uuid do
        allow_nil? false
      end

      argument :expected_revision_id, :uuid do
        allow_nil? false
      end

      argument :segments, {:array, :map} do
        allow_nil? false
        constraints min_length: 1, max_length: 32
      end

      argument :reason_code, :string do
        allow_nil? false
        constraints min_length: 1, max_length: 80, trim?: true
      end

      argument :idempotency_key, :uuid do
        allow_nil? false
      end

      argument :causation_id, :uuid do
        allow_nil? false
      end

      run Chimwemwe.Platform.TemporalQualification.CorrectRevision
    end
  end

  policies do
    policy action(:publish_revision) do
      forbid_unless actor_present()

      authorize_if {Chimwemwe.Platform.Policy.HasCapability,
                    capability: "platform.temporal_qualification.revisions.publish"}
    end

    policy action(:correct_revision) do
      forbid_unless actor_present()

      authorize_if {Chimwemwe.Platform.Policy.HasCapability,
                    capability: "platform.temporal_qualification.revisions.correct"}
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

    attribute :current_revision_id, :uuid do
      allow_nil? true
      public? false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
