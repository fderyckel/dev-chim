defmodule Chimwemwe.Platform.ModuleLifecycle.TransitionResult do
  @moduledoc """
  Stable result of one governed module-lifecycle transition.

  Exact idempotent retries return the same lifecycle, work, and evidence
  references. The result is operational evidence; it grants no authority.
  """

  @enforce_keys [
    :id,
    :transition,
    :module_key,
    :module_version,
    :state,
    :lock_version,
    :audit_reference,
    :event_id
  ]
  defstruct [
    :id,
    :transition,
    :module_key,
    :module_version,
    :state,
    :lock_version,
    :audit_reference,
    :event_id,
    :work_item_id,
    :parked_work_count,
    :requeued_work_count,
    :replay_from_cursor,
    :projection_version
  ]

  @type transition :: :deactivated | :mandatory_work_completed | :reactivated

  @type t :: %__MODULE__{
          id: String.t(),
          transition: transition(),
          module_key: String.t(),
          module_version: String.t(),
          state: :active | :inactive,
          lock_version: pos_integer(),
          audit_reference: String.t(),
          event_id: String.t(),
          work_item_id: String.t() | nil,
          parked_work_count: non_neg_integer() | nil,
          requeued_work_count: non_neg_integer() | nil,
          replay_from_cursor: non_neg_integer() | nil,
          projection_version: pos_integer()
        }
end
