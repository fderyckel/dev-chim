defmodule AshFoundationLab.RetainedDataMigration.ExpandFoundationRecordName do
  use Ecto.Migration

  @lock_timeout "250ms"

  def up do
    execute("SET LOCAL lock_timeout = '#{@lock_timeout}'")

    alter table(:foundation_records) do
      add(:canonical_name, :text)
    end

    execute("""
    ALTER TABLE foundation_records
    ADD CONSTRAINT foundation_records_canonical_name_must_not_be_empty
    CHECK (canonical_name IS NULL OR char_length(canonical_name) > 0)
    NOT VALID
    """)
  end

  def down do
    execute("SET LOCAL lock_timeout = '#{@lock_timeout}'")

    execute("""
    ALTER TABLE foundation_records
    DROP CONSTRAINT foundation_records_canonical_name_must_not_be_empty
    """)

    alter table(:foundation_records) do
      remove(:canonical_name)
    end
  end
end
