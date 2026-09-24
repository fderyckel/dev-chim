defmodule Chimwemwe.Platform.Authority.RoleInclusion do
  @moduledoc """
  Tenant-qualified directed composition edge between two renameable roles.

  PostgreSQL enforces acyclicity for every write path; the application must also
  serialize graph mutations before Slice 1G exposes a named composition action.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_role_inclusions"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_role_inclusions_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :role_id, :included_role_id],
        name: "platform_role_inclusions_unique_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :included_role_id],
        name: "platform_role_inclusions_included_role_index",
        all_tenants?: true
      )
    end

    references do
      reference(:role,
        name: "role_inclusions_role_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )

      reference(:included_role,
        name: "role_inclusions_included_role_tenant_fkey",
        on_delete: :restrict,
        match_tenant?: true,
        match_type: :full
      )
    end

    check_constraints do
      check_constraint([:role_id, :included_role_id], "platform_role_cannot_include_itself",
        check: "role_id <> included_role_id"
      )
    end

    custom_statements do
      statement :platform_role_inclusions_acyclic_function do
        global? true
        after_tables(["platform_role_inclusions"])

        up("""
        CREATE FUNCTION enforce_platform_role_inclusion_acyclicity()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $$
        BEGIN
          PERFORM pg_advisory_xact_lock(
            hashtextextended('platform-role-inclusions:' || NEW.tenant_id::text, 0)
          );

          IF EXISTS (
            WITH RECURSIVE descendants(role_id) AS (
              SELECT NEW.included_role_id

              UNION

              SELECT inclusion.included_role_id
              FROM platform_role_inclusions AS inclusion
              JOIN descendants
                ON descendants.role_id = inclusion.role_id
              WHERE inclusion.tenant_id = NEW.tenant_id
                AND inclusion.id <> NEW.id
            )
            SELECT 1
            FROM descendants
            WHERE descendants.role_id = NEW.role_id
          ) THEN
            RAISE EXCEPTION USING
              ERRCODE = '23514',
              CONSTRAINT = 'platform_role_inclusions_acyclic',
              MESSAGE = 'role inclusion would create a cycle';
          END IF;

          RETURN NEW;
        END;
        $$;
        """)

        down("DROP FUNCTION enforce_platform_role_inclusion_acyclicity();")
      end

      statement :platform_role_inclusions_acyclic_trigger do
        global? true
        after_tables(["platform_role_inclusions"])

        up("""
        CREATE TRIGGER platform_role_inclusions_enforce_acyclicity
        BEFORE INSERT OR UPDATE OF tenant_id, role_id, included_role_id
        ON platform_role_inclusions
        FOR EACH ROW
        EXECUTE FUNCTION enforce_platform_role_inclusion_acyclicity();
        """)

        down(
          "DROP TRIGGER platform_role_inclusions_enforce_acyclicity ON platform_role_inclusions;"
        )
      end
    end
  end

  multitenancy do
    strategy :attribute
    attribute :tenant_id
    global? false
  end

  relationships do
    belongs_to :role, Chimwemwe.Platform.Authority.Role do
      source_attribute :role_id
      destination_attribute :id
      define_attribute? false
      public? false
    end

    belongs_to :included_role, Chimwemwe.Platform.Authority.Role do
      source_attribute :included_role_id
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

    attribute :role_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :included_role_id, :uuid do
      allow_nil? false
      public? false
    end

    create_timestamp :inserted_at
  end
end
