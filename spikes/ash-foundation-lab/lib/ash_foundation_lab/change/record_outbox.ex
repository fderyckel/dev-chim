defmodule AshFoundationLab.Change.RecordOutbox do
  @moduledoc false

  use Ash.Resource.Change

  alias Ash.Error.Changes.InvalidChanges
  alias AshFoundationLab.Repo
  alias Ecto.Adapters.SQL
  alias Ecto.UUID

  @event_type "foundation_record.submitted_for_review"
  @schema_version 1
  @classification "internal"

  @impl true
  def change(changeset, _opts, _context) do
    audit_reference = UUID.generate()
    event_id = UUID.generate()

    changeset
    |> Ash.Changeset.force_change_attribute(:audit_reference, audit_reference)
    |> Ash.Changeset.after_action(fn changeset, record ->
      actor = changeset.context[:private][:actor]

      insert_event!(
        event_id,
        record,
        actor,
        audit_reference,
        Ash.Changeset.get_argument(changeset, :correlation_id),
        Ash.Changeset.get_argument(changeset, :causation_id)
      )

      if changeset.context[:inject_outbox_failure?] do
        {:error,
         InvalidChanges.exception(message: "injected failure after transactional outbox insert")}
      else
        {:ok, record}
      end
    end)
  end

  defp insert_event!(
         event_id,
         record,
         actor,
         audit_reference,
         correlation_id,
         causation_id
       ) do
    SQL.query!(
      Repo,
      """
      INSERT INTO outbox_events (
        id,
        tenant_id,
        actor_id,
        aggregate_type,
        aggregate_id,
        event_type,
        schema_version,
        correlation_id,
        causation_id,
        audit_reference,
        classification,
        payload,
        occurred_at,
        inserted_at
      )
      VALUES (
        $1, $2, $3, 'foundation_record', $4, $5, $6, $7, $8, $9, $10,
        jsonb_build_object('to_status', 'in_review'), NOW(), NOW()
      )
      """,
      [
        dump_uuid(event_id),
        dump_uuid(record.tenant_id),
        dump_uuid(actor.id),
        dump_uuid(record.id),
        @event_type,
        @schema_version,
        dump_uuid(correlation_id),
        dump_uuid(causation_id),
        dump_uuid(audit_reference),
        @classification
      ]
    )
  end

  defp dump_uuid(value), do: UUID.dump!(value)
end
