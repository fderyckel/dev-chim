defmodule Chimwemwe.Platform.Outbox.ReplayInput do
  @moduledoc "Exact, immutable input for one governed dead-letter replay."

  @enforce_keys [
    :causation_id,
    :event_id,
    :expected_lock_version,
    :idempotency_key,
    :reason_code
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          causation_id: String.t(),
          event_id: String.t(),
          expected_lock_version: pos_integer(),
          idempotency_key: String.t(),
          reason_code: String.t()
        }
end
