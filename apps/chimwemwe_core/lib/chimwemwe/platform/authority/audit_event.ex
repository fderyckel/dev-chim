defmodule Chimwemwe.Platform.Authority.AuditEvent do
  @moduledoc """
  Immutable, tenant-owned evidence for a committed authority action.

  The named action writes this record transactionally. It has no direct action
  surface and is not a general temporal-record or security-audit subsystem.
  """

  use Chimwemwe.Platform.Resource,
    domain: Chimwemwe.Platform,
    data_layer: AshPostgres.DataLayer,
    ownership: :tenant_owned

  postgres do
    table "platform_authority_audit_events"
    repo(Chimwemwe.Repo)

    custom_indexes do
      index([:id, :tenant_id],
        name: "platform_authority_audit_events_id_tenant_index",
        unique: true,
        all_tenants?: true
      )

      index([:tenant_id, :aggregate_type, :aggregate_id, :occurred_at, :id],
        name: "platform_authority_audit_events_aggregate_index",
        all_tenants?: true
      )
    end

    check_constraints do
      check_constraint(:action_name, "platform_authority_audit_action_must_not_be_empty",
        check: "char_length(action_name) BETWEEN 1 AND 160"
      )

      check_constraint(:aggregate_type, "platform_authority_audit_aggregate_must_not_be_empty",
        check: "char_length(aggregate_type) BETWEEN 1 AND 120"
      )

      check_constraint(
        [:before_version, :after_version],
        "platform_authority_audit_versions_must_be_consecutive",
        check: "before_version >= 0 AND after_version = before_version + 1"
      )

      check_constraint(:change_summary, "platform_authority_audit_change_must_be_an_object",
        check: "jsonb_typeof(change_summary) = 'object'"
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

    attribute :actor_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :action_name, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 160
    end

    attribute :aggregate_type, :string do
      allow_nil? false
      public? false
      constraints min_length: 1, max_length: 120
    end

    attribute :aggregate_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :idempotency_key, :uuid do
      allow_nil? false
      public? false
    end

    attribute :correlation_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :causation_id, :uuid do
      allow_nil? false
      public? false
    end

    attribute :before_version, :integer do
      allow_nil? false
      public? false
      constraints min: 0
    end

    attribute :after_version, :integer do
      allow_nil? false
      public? false
      constraints min: 1
    end

    attribute :change_summary, :map do
      allow_nil? false
      public? false
    end

    attribute :occurred_at, :utc_datetime_usec do
      allow_nil? false
      public? false
    end

    create_timestamp :inserted_at
  end
end
