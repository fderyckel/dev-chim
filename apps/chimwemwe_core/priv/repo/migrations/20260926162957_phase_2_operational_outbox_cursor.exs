defmodule Chimwemwe.Repo.Migrations.Phase2OperationalOutboxCursor do
  @moduledoc """
  Adds the immutable outbox stream position used by cursor paging and module reconciliation.

  AshPostgres generated the resource-shaped change. Review converted it to a compatible
  sequence-backed expansion, an ordered retained-row backfill, a positive-value constraint,
  and a rollback guard that preserves cursor evidence.
  """

  use Ecto.Migration

  def up do
    execute("CREATE SEQUENCE IF NOT EXISTS platform_outbox_events_stream_position_seq")

    alter table(:platform_outbox_events) do
      add(:stream_position, :bigint,
        null: true,
        default: fragment("nextval('platform_outbox_events_stream_position_seq')")
      )
    end

    execute("""
    WITH ordered AS (
      SELECT id,
             nextval('platform_outbox_events_stream_position_seq') AS stream_position
        FROM platform_outbox_events
       WHERE stream_position IS NULL
       ORDER BY occurred_at, id
    )
    UPDATE platform_outbox_events AS event
       SET stream_position = ordered.stream_position
      FROM ordered
     WHERE event.id = ordered.id
    """)

    execute("""
    ALTER SEQUENCE platform_outbox_events_stream_position_seq
      OWNED BY platform_outbox_events.stream_position
    """)

    alter table(:platform_outbox_events) do
      modify(:stream_position, :bigint, null: false)
    end

    create constraint(
             :platform_outbox_events,
             :platform_outbox_stream_position_must_be_positive,
             check: "stream_position >= 1"
           )

    create index(:platform_outbox_events, [:tenant_id, :stream_position],
             name: "platform_outbox_events_stream_position_index",
             unique: true
           )
  end

  def down do
    execute("""
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM platform_outbox_events LIMIT 1) THEN
        RAISE EXCEPTION
          'cannot roll back operational outbox cursor after event evidence is retained';
      END IF;
    END
    $$
    """)

    drop_if_exists(
      index(:platform_outbox_events, [:tenant_id, :stream_position],
        name: "platform_outbox_events_stream_position_index"
      )
    )

    drop_if_exists(
      constraint(:platform_outbox_events, :platform_outbox_stream_position_must_be_positive)
    )

    alter table(:platform_outbox_events) do
      remove(:stream_position)
    end

    execute("DROP SEQUENCE IF EXISTS platform_outbox_events_stream_position_seq")
  end
end
