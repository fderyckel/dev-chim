defmodule Chimwemwe.People.Person do
  @moduledoc "Private tenant-owned Person; named People.Foundation operations own access."
  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.People,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "people_persons"
    repo(Chimwemwe.Repo)

    custom_statements do
      statement :people_record_guard do
        global? true

        after_tables([
          "people_persons",
          "people_participations",
          "people_staff_account_associations"
        ])

        up("""
        CREATE FUNCTION people_record_guard() RETURNS trigger LANGUAGE plpgsql AS $$
        DECLARE
        part people_participations%ROWTYPE;
        person_version bigint;
        member_actor uuid;
        local_day date;
        proof jsonb;
        BEGIN
        IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'people records require retained history';
        END IF;
        IF TG_OP = 'INSERT' AND NEW.lock_version <> 1 THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'invalid initial people version';
        END IF;
        IF TG_TABLE_NAME = 'people_persons' THEN
        IF TG_OP = 'UPDATE' AND (
        (to_jsonb(NEW) - ARRAY['display_name','lock_version']) IS DISTINCT FROM (to_jsonb(OLD) - ARRAY['display_name','lock_version'])
        OR NEW.lock_version <> OLD.lock_version + 1) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'immutable person identity';
        END IF;
        ELSIF TG_TABLE_NAME = 'people_participations' THEN
        SELECT (statement_timestamp() AT TIME ZONE time_zone)::date INTO local_day
        FROM institutional_units WHERE id = NEW.institutional_unit_id AND tenant_id = NEW.tenant_id AND status = 'published' FOR SHARE;
        IF local_day IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'published exact institution required';
        END IF;
        IF TG_OP = 'UPDATE' AND (
        (to_jsonb(NEW) - ARRAY['effective_until','lock_version']) IS DISTINCT FROM (to_jsonb(OLD) - ARRAY['effective_until','lock_version'])
        OR OLD.effective_until IS NOT NULL OR NEW.effective_until IS NULL
        OR NEW.effective_until < local_day OR NEW.lock_version <> 2 OR OLD.lock_version <> 1) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'invalid participation ending';
        END IF;
        ELSIF TG_TABLE_NAME = 'people_staff_account_associations' THEN
        IF TG_OP = 'UPDATE' THEN
        IF (to_jsonb(NEW) - ARRAY['revoked_at','revoked_by_actor_id','lock_version']) IS DISTINCT FROM (to_jsonb(OLD) - ARRAY['revoked_at','revoked_by_actor_id','lock_version'])
        OR OLD.revoked_at IS NOT NULL OR NEW.revoked_at IS NULL OR NEW.revoked_by_actor_id IS NULL
        OR NEW.lock_version <> 2 OR OLD.lock_version <> 1
        OR NEW.revoked_at < (transaction_timestamp() AT TIME ZONE 'UTC')
        OR NEW.revoked_at > (clock_timestamp() AT TIME ZONE 'UTC') THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'invalid account revocation';
        END IF;
        ELSE
        SELECT * INTO STRICT part FROM people_participations WHERE id = NEW.participation_id AND tenant_id = NEW.tenant_id FOR SHARE;
        SELECT lock_version INTO STRICT person_version FROM people_persons WHERE id = NEW.person_id AND tenant_id = NEW.tenant_id FOR SHARE;
        SELECT actor_id INTO STRICT member_actor FROM platform_tenant_memberships WHERE id = NEW.membership_id AND tenant_id = NEW.tenant_id FOR SHARE;
        SELECT (statement_timestamp() AT TIME ZONE time_zone)::date INTO local_day FROM institutional_units WHERE id = part.institutional_unit_id AND tenant_id = part.tenant_id AND status = 'published' FOR SHARE;
        IF part.person_id <> NEW.person_id OR part.kind <> 'staff' OR local_day IS NULL
        OR part.effective_from > local_day OR (part.effective_until IS NOT NULL AND part.effective_until <= local_day) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'current matching staff participation required';
        END IF;
        proof := NEW.verification;
        IF (jsonb_typeof(proof) = 'object'
        AND proof->>'policy' = 'synthetic.people.staff_account.v1'
        AND proof->>'tenant_id' = NEW.tenant_id::text
        AND proof->>'person_id' = NEW.person_id::text
        AND (proof->>'person_version')::bigint = person_version
        AND proof->>'participation_id' = part.id::text
        AND (proof->>'participation_version')::bigint = part.lock_version
        AND proof->>'membership_id' = NEW.membership_id::text
        AND proof->>'actor_id' = member_actor::text
        AND proof->>'evidence_reference' = NEW.evidence_reference::text
        AND proof->'matched' = 'true'::jsonb AND proof->'human_account' = 'true'::jsonb
        AND (proof->>'checked_at')::timestamptz >= transaction_timestamp()
        AND (proof->>'checked_at')::timestamptz <= clock_timestamp()
        AND proof - ARRAY['policy','tenant_id','person_id','person_version','participation_id','participation_version','membership_id','actor_id','evidence_reference','matched','human_account','checked_at'] = '{}'::jsonb) IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'invalid staff account proof';
        END IF;
        END IF;
        END IF;
        RETURN NEW;
        END $$;
        """)

        down("DROP FUNCTION people_record_guard();")
      end

      statement :people_persons_guard do
        global? true

        after_tables([
          "people_persons",
          "people_participations",
          "people_staff_account_associations"
        ])

        up("""
        CREATE TRIGGER people_persons_guard BEFORE INSERT OR UPDATE OR DELETE ON people_persons FOR EACH ROW EXECUTE FUNCTION people_record_guard();
        """)

        down("DROP TRIGGER people_persons_guard ON people_persons;")
      end

      statement :people_participations_guard do
        global? true

        after_tables([
          "people_persons",
          "people_participations",
          "people_staff_account_associations"
        ])

        up("""
        CREATE TRIGGER people_participations_guard BEFORE INSERT OR UPDATE OR DELETE ON people_participations FOR EACH ROW EXECUTE FUNCTION people_record_guard();
        """)

        down("DROP TRIGGER people_participations_guard ON people_participations;")
      end

      statement :people_staff_account_associations_guard do
        global? true

        after_tables([
          "people_persons",
          "people_participations",
          "people_staff_account_associations"
        ])

        up("""
        CREATE TRIGGER people_staff_account_associations_guard BEFORE INSERT OR UPDATE OR DELETE ON people_staff_account_associations FOR EACH ROW EXECUTE FUNCTION people_record_guard();
        """)

        down(
          "DROP TRIGGER people_staff_account_associations_guard ON people_staff_account_associations;"
        )
      end
    end

    custom_indexes do
      index([:id, :tenant_id],
        name: "people_persons_id_tenant_idx",
        unique: true,
        all_tenants?: true
      )
    end

    check_constraints do
      check_constraint(:display_name, "people_persons_name",
        check: "char_length(btrim(display_name)) BETWEEN 1 AND 200"
      )

      check_constraint(:lock_version, "people_persons_version", check: "lock_version >= 1")
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

    attribute :display_name, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 200
    end

    attribute :lock_version, :integer do
      allow_nil? false
      public? false
      default 1
      constraints min: 1
    end

    create_timestamp :inserted_at
  end
end
