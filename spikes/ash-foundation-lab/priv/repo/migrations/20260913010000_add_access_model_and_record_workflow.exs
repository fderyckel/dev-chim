defmodule AshFoundationLab.Repo.Migrations.AddAccessModelAndRecordWorkflow do
  use Ecto.Migration

  def change do
    create table(:tenants, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :name, :text, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create constraint(:tenants, :tenant_name_must_not_be_empty,
             check: "char_length(name) > 0"
           )

    create table(:actors, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false
      add :name, :text, null: false
      add :kind, :text, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:actors, [:id, :tenant_id])
    create index(:actors, [:tenant_id])
    create constraint(:actors, :actor_name_must_not_be_empty, check: "char_length(name) > 0")
    create constraint(:actors, :actor_kind_must_be_known, check: "kind IN ('human', 'service')")

    create table(:roles, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false
      add :name, :text, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:roles, [:id, :tenant_id])
    create unique_index(:roles, [:tenant_id, :name])
    create constraint(:roles, :role_name_must_not_be_empty, check: "char_length(name) > 0")

    create table(:capabilities, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false
      add :key, :text, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:capabilities, [:id, :tenant_id])
    create unique_index(:capabilities, [:tenant_id, :key])
    create constraint(:capabilities, :capability_key_must_not_be_empty,
             check: "char_length(key) > 0"
           )

    create table(:actor_roles, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :actor_id,
          references(:actors,
            type: :uuid,
            with: [tenant_id: :tenant_id],
            match: :full,
            on_delete: :delete_all,
            name: :actor_roles_actor_tenant_fkey
          ),
          null: false

      add :role_id,
          references(:roles,
            type: :uuid,
            with: [tenant_id: :tenant_id],
            match: :full,
            on_delete: :delete_all,
            name: :actor_roles_role_tenant_fkey
          ),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:actor_roles, [:tenant_id, :actor_id, :role_id])
    create index(:actor_roles, [:tenant_id, :role_id])

    create table(:role_capabilities, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :role_id,
          references(:roles,
            type: :uuid,
            with: [tenant_id: :tenant_id],
            match: :full,
            on_delete: :delete_all,
            name: :role_capabilities_role_tenant_fkey
          ),
          null: false

      add :capability_id,
          references(:capabilities,
            type: :uuid,
            with: [tenant_id: :tenant_id],
            match: :full,
            on_delete: :delete_all,
            name: :role_capabilities_capability_tenant_fkey
          ),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:role_capabilities, [:tenant_id, :role_id, :capability_id])
    create index(:role_capabilities, [:tenant_id, :capability_id])

    create table(:role_inclusions, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :tenant_id, references(:tenants, type: :uuid, on_delete: :restrict), null: false

      add :role_id,
          references(:roles,
            type: :uuid,
            with: [tenant_id: :tenant_id],
            match: :full,
            on_delete: :delete_all,
            name: :role_inclusions_role_tenant_fkey
          ),
          null: false

      add :included_role_id,
          references(:roles,
            type: :uuid,
            with: [tenant_id: :tenant_id],
            match: :full,
            on_delete: :delete_all,
            name: :role_inclusions_included_role_tenant_fkey
          ),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:role_inclusions, [:tenant_id, :role_id, :included_role_id])
    create index(:role_inclusions, [:tenant_id, :included_role_id])

    create constraint(:role_inclusions, :role_cannot_include_itself,
             check: "role_id <> included_role_id"
           )

    execute(
      """
      ALTER TABLE foundation_records
      ADD CONSTRAINT foundation_records_tenant_id_fkey
      FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT
      """,
      """
      ALTER TABLE foundation_records
      DROP CONSTRAINT foundation_records_tenant_id_fkey
      """
    )

    create unique_index(:foundation_records, [:id, :tenant_id])

    alter table(:foundation_records) do
      add :status, :text, null: false, default: "draft"
      add :lock_version, :bigint, null: false, default: 1
    end

    create constraint(:foundation_records, :foundation_record_status_must_be_known,
             check: "status IN ('draft', 'in_review')"
           )

    create constraint(:foundation_records, :foundation_record_lock_version_must_be_positive,
             check: "lock_version >= 1"
           )
  end
end
