defmodule Chimwemwe.Platform.TemporalQualification.ImportResult do
  @moduledoc false

  @enforce_keys [
    :import_id,
    :record_id,
    :version,
    :state,
    :source_snapshot_digest,
    :source_identifier_digest,
    :mapping_revision,
    :recorded_at,
    :audit_reference,
    :event_id
  ]
  defstruct @enforce_keys ++
              [:predecessor_record_id, :conflict_code, :aggregate_id, :revision_id]

  @type t :: %__MODULE__{
          import_id: String.t(),
          record_id: String.t(),
          version: pos_integer(),
          predecessor_record_id: String.t() | nil,
          state: :baseline | :reconciliation_required | :reconciled,
          conflict_code: String.t() | nil,
          source_snapshot_digest: binary(),
          source_identifier_digest: binary(),
          mapping_revision: String.t(),
          aggregate_id: String.t() | nil,
          revision_id: String.t() | nil,
          recorded_at: NaiveDateTime.t(),
          audit_reference: String.t(),
          event_id: String.t()
        }
end
