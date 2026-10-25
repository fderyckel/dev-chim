defmodule Chimwemwe.Identity.StaffDirectoryEntry do
  @moduledoc "Private synthetic staff login profile; named StaffDirectory actions own access."
  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Identity,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "identity_staff_directory_entries"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id], unique: true, all_tenants?: true)
      index([:association_id, :tenant_id], unique: true, all_tenants?: true)
      index([:membership_id, :tenant_id], unique: true, all_tenants?: true)
      index([:account_id, :tenant_id], unique: true, all_tenants?: true)
    end

    references do
      reference(:association, on_delete: :restrict, match_tenant?: true, match_type: :full)
      reference(:membership, on_delete: :restrict, match_tenant?: true, match_type: :full)
      reference(:account, on_delete: :restrict, match_type: :simple)
    end

    check_constraints do
      check_constraint(:locale, "identity_staff_directory_locale",
        check: "locale IN ('en', 'fr', 'en-MW')"
      )

      check_constraint(:display_name, "identity_staff_directory_display_name",
        check: "char_length(btrim(display_name)) BETWEEN 1 AND 200"
      )

      check_constraint(:given_name, "identity_staff_directory_given_name",
        check: "given_name IS NULL OR char_length(btrim(given_name)) BETWEEN 1 AND 200"
      )

      check_constraint(:family_name, "identity_staff_directory_family_name",
        check: "family_name IS NULL OR char_length(btrim(family_name)) BETWEEN 1 AND 200"
      )

      check_constraint(:lock_version, "identity_staff_directory_version",
        check: "lock_version >= 1"
      )

      check_constraint(:access_version, "identity_staff_directory_access_version",
        check: "access_version >= 1"
      )
    end

    custom_statements do
      statement :staff_directory_guard_function do
        global? true
        after_tables(["identity_staff_directory_entries"])

        up("""
        CREATE FUNCTION identity_staff_directory_guard() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN
          IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'staff directory records require retained history';
          ELSIF TG_OP = 'UPDATE' THEN
            IF (to_jsonb(NEW) - ARRAY['given_name','family_name','display_name','locale','enabled','access_version','lock_version','updated_at'])
              IS DISTINCT FROM (to_jsonb(OLD) - ARRAY['given_name','family_name','display_name','locale','enabled','access_version','lock_version','updated_at'])
              OR NEW.lock_version <> OLD.lock_version + 1
              OR NEW.access_version NOT IN (OLD.access_version, OLD.access_version + 1)
              OR (NEW.enabled IS DISTINCT FROM OLD.enabled AND NEW.access_version <> OLD.access_version + 1) THEN
              RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'immutable staff directory identity';
            END IF;
          ELSE
            IF NEW.lock_version <> 1 OR NEW.access_version <> 1 OR NOT EXISTS (
              SELECT 1 FROM people_staff_account_associations s
              JOIN people_participations p ON p.id=s.participation_id AND p.tenant_id=s.tenant_id AND p.person_id=s.person_id
              JOIN institutional_units u ON u.id=p.institutional_unit_id AND u.tenant_id=p.tenant_id
              JOIN platform_tenant_memberships m ON m.id=s.membership_id AND m.tenant_id=s.tenant_id
              JOIN identity_accounts a ON a.id=NEW.account_id AND a.actor_id=m.actor_id
              WHERE s.id=NEW.association_id AND s.tenant_id=NEW.tenant_id AND s.membership_id=NEW.membership_id
                AND m.actor_id=NEW.actor_id AND s.verification->>'actor_id'=m.actor_id::text
                AND s.revoked_at IS NULL AND p.kind='staff' AND u.status='published'
                AND p.effective_from <= (statement_timestamp() AT TIME ZONE u.time_zone)::date
                AND (p.effective_until IS NULL OR p.effective_until > (statement_timestamp() AT TIME ZONE u.time_zone)::date)
            ) THEN
              RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'current exact staff credential chain required';
            END IF;
          END IF;
          RETURN NEW;
        END $$;
        """)

        down("DROP FUNCTION identity_staff_directory_guard();")
      end

      statement :staff_directory_guard_trigger do
        global? true
        after_tables(["identity_staff_directory_entries"])

        up(
          "CREATE TRIGGER identity_staff_directory_guard BEFORE INSERT OR UPDATE OR DELETE ON identity_staff_directory_entries FOR EACH ROW EXECUTE FUNCTION identity_staff_directory_guard();"
        )

        down("""
        DO $$ BEGIN
          IF EXISTS (SELECT 1 FROM identity_staff_directory_entries) THEN
            RAISE EXCEPTION 'retained staff directory entries require forward repair';
          END IF;
          DROP TRIGGER identity_staff_directory_guard ON identity_staff_directory_entries;
        END $$;
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
    belongs_to :association, Chimwemwe.People.StaffAccountAssociation do
      source_attribute :association_id
      define_attribute? false
      public? false
    end

    belongs_to :membership, Chimwemwe.Platform.Authority.Membership do
      source_attribute :membership_id
      define_attribute? false
      public? false
    end

    belongs_to :account, Chimwemwe.Identity.Account do
      source_attribute :account_id
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

    for key <- [:tenant_id, :association_id, :membership_id, :actor_id, :account_id] do
      attribute key, :uuid do
        allow_nil? false
        public? false
      end
    end

    for key <- [:given_name, :family_name] do
      attribute key, :string do
        allow_nil? true
        public? false
        constraints max_length: 200
      end
    end

    attribute :display_name, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 200
    end

    attribute :locale, :string do
      allow_nil? false
      public? false
      constraints match: ~r/^(en|fr|en-MW)$/
    end

    attribute :enabled, :boolean do
      allow_nil? false
      public? false
      default true
    end

    attribute :lock_version, :integer do
      allow_nil? false
      public? false
      default 1
      constraints min: 1
    end

    attribute :access_version, :integer do
      allow_nil? false
      public? false
      default 1
      constraints min: 1
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
end
