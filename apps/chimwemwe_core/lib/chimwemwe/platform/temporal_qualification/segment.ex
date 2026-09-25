defmodule Chimwemwe.Platform.TemporalQualification.Segment do
  @moduledoc """
  Immutable effective-time segment inside one qualification revision.

  PostgreSQL serializes inserts per tenant and revision and rejects half-open
  interval overlap only within that revision. Historical revisions may overlap.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_temporal_qualification_segments"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_temporal_qualification_segments_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :revision_id, :effective_from, :id],
        name: "platform_temporal_qualification_segment_effective_index",
        all_tenants?: true
      )
    end

    references do
      reference(:revision,
        name: "platform_temporal_segment_revision_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:aggregate,
        name: "platform_temporal_segment_aggregate_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint(
        [:effective_from, :effective_until],
        "platform_temporal_segment_interval_valid",
        check: "effective_from < effective_until"
      )

      check_constraint(:value, "platform_temporal_segment_value_not_empty",
        check: "char_length(value) BETWEEN 1 AND 80"
      )
    end

    custom_statements do
      statement :platform_temporal_qualification_segment_guard_function do
        global? true
        after_tables(["platform_temporal_qualification_segments"])

        up("""
        CREATE FUNCTION guard_platform_temporal_qualification_segment()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $$
        BEGIN
          IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION USING
              ERRCODE = '23514',
              CONSTRAINT = 'platform_temporal_qualification_segment_delete_forbidden',
              MESSAGE = 'temporal qualification segment deletion is forbidden';
          END IF;

          IF TG_OP = 'UPDATE' THEN
            RAISE EXCEPTION USING
              ERRCODE = '23514',
              CONSTRAINT = 'platform_temporal_qualification_segment_immutable',
              MESSAGE = 'temporal qualification segments are immutable';
          END IF;

          PERFORM pg_advisory_xact_lock(
            hashtextextended(
              'platform-temporal-qualification-segment:' ||
                NEW.tenant_id::text || ':' || NEW.revision_id::text,
              0
            )
          );

          IF EXISTS (
            SELECT 1
            FROM platform_temporal_qualification_segments AS segment
            WHERE segment.tenant_id = NEW.tenant_id
              AND segment.revision_id = NEW.revision_id
              AND NEW.effective_from < segment.effective_until
              AND segment.effective_from < NEW.effective_until
          ) THEN
            RAISE EXCEPTION USING
              ERRCODE = '23P01',
              CONSTRAINT = 'platform_temporal_qualification_segment_no_overlap',
              MESSAGE = 'temporal qualification segments overlap';
          END IF;

          RETURN NEW;
        END;
        $$;
        """)

        down("DROP FUNCTION guard_platform_temporal_qualification_segment();")
      end

      statement :platform_temporal_qualification_segment_guard_trigger do
        global? true
        after_tables(["platform_temporal_qualification_segments"])

        up("""
        CREATE TRIGGER platform_temporal_qualification_segment_guard
        BEFORE INSERT OR UPDATE OR DELETE
        ON platform_temporal_qualification_segments
        FOR EACH ROW
        EXECUTE FUNCTION guard_platform_temporal_qualification_segment();
        """)

        down("""
        DROP TRIGGER platform_temporal_qualification_segment_guard
          ON platform_temporal_qualification_segments;
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
    belongs_to :revision, Chimwemwe.Platform.TemporalQualification.Revision do
      source_attribute :revision_id
      destination_attribute :id
      define_attribute? false
      public? false
    end

    belongs_to :aggregate, Chimwemwe.Platform.TemporalQualification.Aggregate do
      source_attribute :aggregate_id
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

    attribute :revision_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :effective_from, :date do
      allow_nil? false
      public? false
    end

    attribute :effective_until, :date do
      allow_nil? false
      public? false
    end

    attribute :value, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 80
    end
  end
end
