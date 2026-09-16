defmodule AshFoundationLab.RetainedDataMigration.EnforceFoundationRecordDualWrite do
  use Ecto.Migration

  @lock_timeout "250ms"

  def up do
    execute("SET LOCAL lock_timeout = '#{@lock_timeout}'")
    execute("LOCK TABLE foundation_records IN SHARE ROW EXCLUSIVE MODE")

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM foundation_records
        WHERE canonical_name IS NULL
      ) THEN
        RAISE EXCEPTION USING
          ERRCODE = '23514',
          CONSTRAINT = 'foundation_records_canonical_name_backfill_complete',
          MESSAGE = 'canonical name backfill is incomplete';
      END IF;
    END;
    $$
    """)

    execute("""
    ALTER TABLE foundation_records
    ADD CONSTRAINT foundation_records_canonical_name_must_be_present
    CHECK (canonical_name IS NOT NULL)
    NOT VALID
    """)
  end

  def down do
    execute("SET LOCAL lock_timeout = '#{@lock_timeout}'")

    execute("""
    ALTER TABLE foundation_records
    DROP CONSTRAINT foundation_records_canonical_name_must_be_present
    """)
  end
end
