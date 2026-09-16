defmodule AshFoundationLab.RetainedDataMigration.ValidateFoundationRecordName do
  use Ecto.Migration

  @lock_timeout "250ms"

  def up do
    execute("SET LOCAL lock_timeout = '#{@lock_timeout}'")

    execute("""
    ALTER TABLE foundation_records
    VALIDATE CONSTRAINT foundation_records_canonical_name_must_not_be_empty
    """)

    execute("""
    ALTER TABLE foundation_records
    VALIDATE CONSTRAINT foundation_records_canonical_name_must_be_present
    """)
  end

  def down do
    execute("SELECT 1")
  end
end
