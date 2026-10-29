defmodule Chimwemwe.Communications.Notice do
  @moduledoc "Closed Restricted COMM-1 storage; named session-bound actions only."
  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Communications,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table("communications_notices")
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        unique: true,
        all_tenants?: true,
        name: "communications_notices_id_tenant_idx"
      )
    end

    references do
      reference(:institution, on_delete: :restrict, match_tenant?: true, match_type: :full)

      reference(:submitted_preparation,
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :simple
      )
    end

    check_constraints do
      check_constraint(:state, "communications_notice_state",
        check: "state IN ('draft','pending','published','withdrawn')"
      )

      check_constraint(:lock_version, "communications_notice_versions",
        check: "lock_version > 0 AND current_revision_number BETWEEN 0 AND 2"
      )

      check_constraint(:title, "communications_notice_text",
        check: "char_length(title) BETWEEN 1 AND 120 AND char_length(body) BETWEEN 1 AND 2000"
      )
    end

    custom_statements do
      statement :communications_notice_guard do
        global?(true)

        after_tables([
          "communications_notices",
          "communications_preparations",
          "communications_revisions",
          "communications_engagements"
        ])

        up("""
        DO $migration$ BEGIN
        CREATE FUNCTION communications_notice_guard() RETURNS trigger LANGUAGE plpgsql AS $$
        DECLARE amount integer;
        BEGIN
          IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='communication state is retained';
          END IF;
          IF TG_OP = 'INSERT' THEN
            PERFORM pg_advisory_xact_lock(hashtextextended('communications-institution:' || NEW.tenant_id::text || ':' || NEW.institution_id::text,0));
            SELECT count(*) INTO amount FROM communications_notices WHERE tenant_id=NEW.tenant_id AND institution_id=NEW.institution_id;
            IF amount >= 5 OR NEW.lock_version <> 1 OR NEW.current_revision_number <> 0 OR NEW.state <> 'draft' THEN
              RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='communication creation bound';
            END IF;
          ELSE
            IF (NEW.id,NEW.tenant_id,NEW.institution_id,NEW.author_id,NEW.inserted_at)
                IS DISTINCT FROM (OLD.id,OLD.tenant_id,OLD.institution_id,OLD.author_id,OLD.inserted_at)
                OR OLD.state='withdrawn' OR NEW.lock_version <> OLD.lock_version+1
                OR NEW.current_revision_number NOT BETWEEN OLD.current_revision_number AND OLD.current_revision_number+1
                OR (OLD.current_revision_number>0 AND (NEW.receipt_required,NEW.title,NEW.body) IS DISTINCT FROM (OLD.receipt_required,OLD.title,OLD.body)) THEN
              RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='communication transition rejected';
            END IF;
          END IF;
          IF NEW.submitted_preparation_id IS NOT NULL AND NOT EXISTS
            (SELECT 1 FROM communications_preparations p WHERE p.tenant_id=NEW.tenant_id AND p.id=NEW.submitted_preparation_id AND p.notice_id=NEW.id) THEN
            RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='communication preparation scope rejected';
          END IF;
          RETURN NEW;
        END $$;
        CREATE TRIGGER communications_notice_guard BEFORE INSERT OR UPDATE OR DELETE ON communications_notices
          FOR EACH ROW EXECUTE FUNCTION communications_notice_guard();
        CREATE FUNCTION communications_revision_guard() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN
          IF NOT EXISTS (
            SELECT 1 FROM communications_notices n JOIN communications_preparations p
              ON p.tenant_id=n.tenant_id AND p.notice_id=n.id
            WHERE n.tenant_id=NEW.tenant_id AND n.id=NEW.notice_id AND p.id=NEW.preparation_id
              AND n.state='pending' AND n.submitted_preparation_id=p.id AND n.lock_version=p.base_version+1
              AND n.current_revision_number+1=NEW.number AND n.receipt_required=NEW.receipt_required
              AND (p.proposer_id,p.title,p.body,p.reason,p.receipt_required)
                IS NOT DISTINCT FROM (NEW.proposer_id,NEW.title,NEW.body,NEW.reason,NEW.receipt_required)
              AND p.operation IN ('publish','correct')
          ) OR (NEW.eligibility->>'audience')::int NOT BETWEEN 1 AND 25
             OR (NEW.eligibility->>'eligible')::int < 0
             OR (NEW.eligibility->>'no_eligible_account')::int < 0
             OR (NEW.eligibility->>'no_current_access')::int < 0
             OR (NEW.eligibility->>'audience')::int <>
               (NEW.eligibility->>'eligible')::int+(NEW.eligibility->>'no_eligible_account')::int+(NEW.eligibility->>'no_current_access')::int THEN
            RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='communication revision scope rejected';
          END IF;
          RETURN NEW;
        END $$;
        CREATE TRIGGER communications_revision_guard BEFORE INSERT ON communications_revisions
          FOR EACH ROW EXECUTE FUNCTION communications_revision_guard();
        CREATE FUNCTION communications_engagement_guard() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM communications_revisions r JOIN communications_notices n
            ON n.tenant_id=r.tenant_id AND n.id=r.notice_id WHERE r.tenant_id=NEW.tenant_id
            AND r.id=NEW.revision_id AND r.notice_id=NEW.notice_id
            AND r.number=n.current_revision_number AND n.state <> 'withdrawn'
            AND (NEW.kind='opening' OR r.receipt_required)) THEN
            RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='communication engagement scope rejected';
          END IF;
          RETURN NEW;
        END $$;
        CREATE TRIGGER communications_engagement_guard BEFORE INSERT ON communications_engagements
          FOR EACH ROW EXECUTE FUNCTION communications_engagement_guard();
        END $migration$;
        """)

        down("""
        DO $migration$ BEGIN
        DROP TRIGGER communications_engagement_guard ON communications_engagements;
        DROP FUNCTION communications_engagement_guard();
        DROP TRIGGER communications_revision_guard ON communications_revisions;
        DROP FUNCTION communications_revision_guard();
        DROP TRIGGER communications_notice_guard ON communications_notices;
        DROP FUNCTION communications_notice_guard();
        END $migration$;
        """)
      end
    end
  end

  multitenancy do
    strategy(:attribute)
    attribute(:tenant_id)
    global?(false)
  end

  relationships do
    belongs_to :institution, Chimwemwe.InstitutionalStructure.InstitutionalUnit do
      source_attribute(:institution_id)
      define_attribute?(false)
      public?(false)
    end

    belongs_to :submitted_preparation, Chimwemwe.Communications.Preparation do
      source_attribute(:submitted_preparation_id)
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

    attribute :institution_id, :uuid do
      allow_nil?(false)
      public?(false)
    end

    attribute :author_id, :uuid do
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

    attribute :receipt_required, :boolean do
      allow_nil?(false)
      public?(false)
    end

    attribute :state, :string do
      allow_nil?(false)
      public?(false)
    end

    attribute :lock_version, :integer do
      allow_nil?(false)
      public?(false)
    end

    attribute :current_revision_number, :integer do
      allow_nil?(false)
      public?(false)
    end

    attribute :submitted_preparation_id, :uuid do
      allow_nil?(true)
      public?(false)
    end

    create_timestamp(:inserted_at)
  end
end
