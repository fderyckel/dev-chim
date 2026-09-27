defmodule Chimwemwe.Platform.TemporalQualification.RetentionResult do
  @moduledoc false

  @enforce_keys [
    :control_id,
    :aggregate_id,
    :scope_id,
    :module_key,
    :state,
    :version,
    :receipt_id,
    :operation,
    :recorded_at,
    :audit_reference,
    :event_id
  ]
  defstruct @enforce_keys ++
              [
                :policy_key,
                :classification,
                :retention_started_on,
                :retain_until,
                :hold_reference_digest,
                :redacted_segment_count,
                :redacted_fact_count,
                :purged_projection_count
              ]

  @type t :: %__MODULE__{
          control_id: String.t(),
          aggregate_id: String.t(),
          scope_id: String.t(),
          module_key: String.t(),
          policy_key: String.t() | nil,
          classification: atom() | nil,
          retention_started_on: Date.t() | nil,
          retain_until: Date.t() | nil,
          state: :retained | :held | :erased,
          version: pos_integer(),
          receipt_id: String.t(),
          operation: :declared | :hold_placed | :hold_released | :erased,
          hold_reference_digest: binary() | nil,
          redacted_segment_count: non_neg_integer() | nil,
          redacted_fact_count: non_neg_integer() | nil,
          purged_projection_count: non_neg_integer() | nil,
          recorded_at: NaiveDateTime.t(),
          audit_reference: String.t(),
          event_id: String.t()
        }
end
