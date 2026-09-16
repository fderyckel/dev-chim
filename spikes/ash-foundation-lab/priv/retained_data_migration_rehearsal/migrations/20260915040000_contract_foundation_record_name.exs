defmodule AshFoundationLab.RetainedDataMigration.ContractFoundationRecordName do
  use Ecto.Migration

  @lock_timeout "250ms"

  def up do
    execute("SET LOCAL lock_timeout = '#{@lock_timeout}'")

    execute("""
    ALTER TABLE foundation_records
    ALTER COLUMN canonical_name SET NOT NULL
    """)

    execute("""
    ALTER TABLE foundation_records
    DROP COLUMN name RESTRICT
    """)
  end

  def down do
    raise Ecto.MigrationError,
          "the destructive contract drops the legacy name column; restore from backup or deploy a forward repair"
  end
end
