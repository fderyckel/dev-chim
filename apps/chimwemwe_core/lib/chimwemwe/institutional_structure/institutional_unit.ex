defmodule Chimwemwe.InstitutionalStructure.InstitutionalUnit do
  @moduledoc "Private synthetic CF-1 InstitutionalUnit resource; named Foundation actions own access."
  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.InstitutionalStructure,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "institutional_units"
    repo(Chimwemwe.Repo)

    custom_statements do
      statement :institution_proof_guard do
        global? true

        after_tables([
          "institutional_units",
          "institution_initial_operator_assignments",
          "institution_publications"
        ])

        up("""
        CREATE FUNCTION institution_proof_guard() RETURNS trigger LANGUAGE plpgsql AS $$
        DECLARE
        u institutional_units%ROWTYPE;
        a institution_initial_operator_assignments%ROWTYPE;
        proof jsonb; local_day date; expected_revision bigint; legal_version bigint;
        BEGIN
        SELECT * INTO STRICT u FROM institutional_units WHERE id = NEW.institutional_unit_id AND tenant_id = NEW.tenant_id FOR UPDATE;
        local_day := (statement_timestamp() AT TIME ZONE u.time_zone)::date;
        proof := NEW.verification;
        IF TG_TABLE_NAME = 'institution_initial_operator_assignments' THEN
        a := NEW;
        expected_revision := 1;
        ELSE
        SELECT * INTO STRICT a FROM institution_initial_operator_assignments WHERE id = NEW.operator_assignment_id AND tenant_id = NEW.tenant_id;
        expected_revision := 2;
        IF a.institutional_unit_id <> u.id OR a.effective_from <> local_day THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'publication basis mismatch';
        END IF;
        END IF;
        SELECT lock_version INTO legal_version FROM organization_legal_entities WHERE id = a.legal_entity_id AND tenant_id = a.tenant_id AND status = 'active' FOR SHARE;
        IF u.status <> 'draft' OR u.lock_version <> expected_revision OR legal_version IS DISTINCT FROM a.legal_entity_version THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'stale institutional basis';
        END IF;
        IF (jsonb_typeof(proof) = 'object'
        AND proof->>'tenant_id' = NEW.tenant_id::text
        AND proof->>'institutional_unit_id' = u.id::text
        AND (proof->>'institution_version')::bigint = expected_revision
        AND proof->>'legal_entity_id' = a.legal_entity_id::text
        AND (proof->>'legal_entity_version')::bigint = legal_version
        AND proof->>'evidence_reference' = a.evidence_reference::text
        AND (proof->>'effective_from')::date = a.effective_from
        AND proof->>'policy_key' = 'synthetic.cf1.initial_operator.v1'
        AND proof->>'jurisdiction' = 'ZZ'
        AND proof->>'evidence_type' = 'synthetic_operating_instrument'
        AND proof->>'impact_policy' = 'cf1.initial_unpublished_root.v1'
        AND proof->'conditions_satisfied' = 'true'::jsonb
        AND proof->'impact_accepted' = 'true'::jsonb
        AND proof->'consumer_keys' = '[]'::jsonb
        AND (proof->>'evidence_version')::uuid IS NOT NULL
        AND (proof->>'issuer_reference')::uuid IS NOT NULL
        AND (proof->>'verifier_actor_id')::uuid IS NOT NULL
        AND (proof->>'impact_reference')::uuid IS NOT NULL
        AND (proof->>'checked_at')::timestamptz >= transaction_timestamp()
        AND (proof->>'checked_at')::timestamptz <= clock_timestamp()
        AND local_day - (proof->>'status_checked_on')::date BETWEEN 0 AND 30
        AND (proof->>'valid_from')::date <= local_day
        AND (proof->>'valid_from')::date <= a.effective_from
        AND (proof->>'valid_until')::date > local_day
        AND (proof->>'valid_until')::date > a.effective_from) IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'invalid institutional proof';
        END IF;
        RETURN NEW;
        END $$;
        """)

        down("DROP FUNCTION institution_proof_guard();")
      end

      statement :institution_initial_operator_assignments_proof do
        global? true

        after_tables([
          "institutional_units",
          "institution_initial_operator_assignments",
          "institution_publications"
        ])

        up("""
        CREATE TRIGGER institution_initial_operator_assignments_proof BEFORE INSERT ON institution_initial_operator_assignments FOR EACH ROW EXECUTE FUNCTION institution_proof_guard();
        """)

        down(
          "DROP TRIGGER institution_initial_operator_assignments_proof ON institution_initial_operator_assignments;"
        )
      end

      statement :institution_publications_proof do
        global? true

        after_tables([
          "institutional_units",
          "institution_initial_operator_assignments",
          "institution_publications"
        ])

        up("""
        CREATE TRIGGER institution_publications_proof BEFORE INSERT ON institution_publications FOR EACH ROW EXECUTE FUNCTION institution_proof_guard();
        """)

        down("DROP TRIGGER institution_publications_proof ON institution_publications;")
      end

      statement :institution_identity_guard do
        global? true

        after_tables([
          "institutional_units",
          "institution_initial_operator_assignments",
          "institution_publications"
        ])

        up("""
        CREATE FUNCTION institution_identity_guard() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN
        IF TG_OP = 'DELETE' THEN RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'institution deletion forbidden'; END IF;
        IF TG_OP = 'INSERT' THEN
        IF NEW.status <> 'draft' OR NEW.lock_version <> 1 OR NOT EXISTS (SELECT 1 FROM pg_timezone_names WHERE name = NEW.time_zone) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'invalid initial institution';
        END IF;
        ELSE
        IF ROW(NEW.id, NEW.tenant_id, NEW.display_name, NEW.classification, NEW.time_zone, NEW.inserted_at)
        IS DISTINCT FROM ROW(OLD.id, OLD.tenant_id, OLD.display_name, OLD.classification, OLD.time_zone, OLD.inserted_at)
        OR OLD.status <> 'draft' OR NEW.lock_version <> OLD.lock_version + 1 THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'invalid institutional transition';
        END IF;
        END IF;
        RETURN NEW;
        END $$;
        """)

        down("DROP FUNCTION institution_identity_guard();")
      end

      statement :institution_fact_guard do
        global? true

        after_tables([
          "institutional_units",
          "institution_initial_operator_assignments",
          "institution_publications"
        ])

        up("""
        CREATE FUNCTION institution_fact_guard() RETURNS trigger LANGUAGE plpgsql AS $$
        BEGIN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'institutional facts are immutable';
        END $$;
        """)

        down("DROP FUNCTION institution_fact_guard();")
      end

      statement :institution_consistency_guard do
        global? true

        after_tables([
          "institutional_units",
          "institution_initial_operator_assignments",
          "institution_publications"
        ])

        up("""
        CREATE FUNCTION institution_consistency_guard() RETURNS trigger LANGUAGE plpgsql AS $$
        DECLARE
        unit_id uuid; unit_tenant uuid; version bigint; assignment uuid; publication uuid; selected_assignment uuid;
        BEGIN
        IF TG_TABLE_NAME = 'institutional_units' THEN unit_id := NEW.id; ELSE unit_id := NEW.institutional_unit_id; END IF;
        unit_tenant := NEW.tenant_id;
        SELECT lock_version INTO version FROM institutional_units WHERE id = unit_id AND tenant_id = unit_tenant FOR UPDATE;
        SELECT id INTO assignment FROM institution_initial_operator_assignments WHERE institutional_unit_id = unit_id AND tenant_id = unit_tenant;
        SELECT id, operator_assignment_id INTO publication, selected_assignment FROM institution_publications WHERE institutional_unit_id = unit_id AND tenant_id = unit_tenant;
        IF version IS NULL OR
        (version = 1 AND (assignment IS NOT NULL OR publication IS NOT NULL)) OR
        (version = 2 AND (assignment IS NULL OR publication IS NOT NULL)) OR
        (version = 3 AND (assignment IS NULL OR publication IS NULL OR selected_assignment IS DISTINCT FROM assignment)) THEN
        RAISE EXCEPTION USING ERRCODE = '23514', MESSAGE = 'inconsistent institutional lifecycle';
        END IF;
        RETURN NEW;
        END $$;
        """)

        down("DROP FUNCTION institution_consistency_guard();")
      end

      statement :institution_identity_trigger do
        global? true

        after_tables([
          "institutional_units",
          "institution_initial_operator_assignments",
          "institution_publications"
        ])

        up("""
        CREATE TRIGGER institution_identity_trigger BEFORE INSERT OR UPDATE OR DELETE ON institutional_units FOR EACH ROW EXECUTE FUNCTION institution_identity_guard();
        """)

        down("DROP TRIGGER institution_identity_trigger ON institutional_units;")
      end

      statement :institution_initial_operator_assignments_immutable do
        global? true

        after_tables([
          "institutional_units",
          "institution_initial_operator_assignments",
          "institution_publications"
        ])

        up("""
        CREATE TRIGGER institution_initial_operator_assignments_immutable BEFORE UPDATE OR DELETE ON institution_initial_operator_assignments FOR EACH ROW EXECUTE FUNCTION institution_fact_guard();
        """)

        down(
          "DROP TRIGGER institution_initial_operator_assignments_immutable ON institution_initial_operator_assignments;"
        )
      end

      statement :institution_publications_immutable do
        global? true

        after_tables([
          "institutional_units",
          "institution_initial_operator_assignments",
          "institution_publications"
        ])

        up("""
        CREATE TRIGGER institution_publications_immutable BEFORE UPDATE OR DELETE ON institution_publications FOR EACH ROW EXECUTE FUNCTION institution_fact_guard();
        """)

        down("DROP TRIGGER institution_publications_immutable ON institution_publications;")
      end

      statement :institutional_units_consistent do
        global? true

        after_tables([
          "institutional_units",
          "institution_initial_operator_assignments",
          "institution_publications"
        ])

        up("""
        CREATE CONSTRAINT TRIGGER institutional_units_consistent AFTER INSERT OR UPDATE ON institutional_units DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION institution_consistency_guard();
        """)

        down("DROP TRIGGER institutional_units_consistent ON institutional_units;")
      end

      statement :institution_initial_operator_assignments_consistent do
        global? true

        after_tables([
          "institutional_units",
          "institution_initial_operator_assignments",
          "institution_publications"
        ])

        up("""
        CREATE CONSTRAINT TRIGGER institution_initial_operator_assignments_consistent AFTER INSERT OR UPDATE ON institution_initial_operator_assignments DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION institution_consistency_guard();
        """)

        down(
          "DROP TRIGGER institution_initial_operator_assignments_consistent ON institution_initial_operator_assignments;"
        )
      end

      statement :institution_publications_consistent do
        global? true

        after_tables([
          "institutional_units",
          "institution_initial_operator_assignments",
          "institution_publications"
        ])

        up("""
        CREATE CONSTRAINT TRIGGER institution_publications_consistent AFTER INSERT OR UPDATE ON institution_publications DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION institution_consistency_guard();
        """)

        down("DROP TRIGGER institution_publications_consistent ON institution_publications;")
      end
    end

    custom_indexes do
      index([:id, :tenant_id],
        name: "institutional_units_id_tenant_idx",
        unique: true,
        all_tenants?: true
      )
    end

    check_constraints do
      check_constraint(:classification, "institutional_units_classification",
        check: "classification = 'institution'"
      )

      check_constraint(:display_name, "institutional_units_name",
        check: "char_length(btrim(display_name)) BETWEEN 1 AND 200"
      )

      check_constraint(:time_zone, "institutional_units_zone",
        check: "char_length(time_zone) BETWEEN 1 AND 100"
      )

      check_constraint(:status, "institutional_units_state",
        check:
          "(status = 'draft' AND lock_version IN (1, 2)) OR (status = 'published' AND lock_version = 3)"
      )
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
      constraints min_length: 1, max_length: 200, trim?: true
    end

    attribute :classification, :atom do
      allow_nil? false
      public? false
      default :institution
      constraints one_of: [:institution]
    end

    attribute :time_zone, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 100
    end

    attribute :status, :atom do
      allow_nil? false
      public? false
      default :draft
      constraints one_of: [:draft, :published]
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
