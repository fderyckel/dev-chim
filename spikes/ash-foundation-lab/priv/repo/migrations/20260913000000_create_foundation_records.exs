defmodule AshFoundationLab.Repo.Migrations.CreateFoundationRecords do
  use Ecto.Migration

  def change do
    create table(:foundation_records, primary_key: false) do
      add :id, :uuid, null: false, primary_key: true
      add :tenant_id, :uuid, null: false
      add :name, :text, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:foundation_records, [:tenant_id])
    create constraint(:foundation_records, :name_must_not_be_empty,
             check: "char_length(name) > 0"
           )
  end
end

